#!/bin/bash

# requires - kubectl
# requires - KUBE_ROOT, KUBE_NS, KUBE_APP, KUBE_ENV, KUBE_DEPLOYMENT_IMAGE, KUBE_INGRESS_HOSTNAME
# optional - DOCKER_REGISTRY, DOCKER_USERNAME, DOCKER_PASSWORD
# optional - DOPPLER_TOKEN, DOPPLER_TOKEN_SECRET_NAME, DOPPLER_MANAGED_SECRET_NAME, KUBE_LABELS

# custom vars

echo "deploy :: starting deployment procedure"
echo "deploy :: kube root - $KUBE_ROOT"
echo "deploy :: kube namespace - $KUBE_NS"
echo "deploy :: kube app - $KUBE_APP"
echo "deploy :: kube env - $KUBE_ENV"
echo "deploy :: kube deployment image - $KUBE_DEPLOYMENT_IMAGE"
echo "deploy :: kube ingress hostname - $KUBE_INGRESS_HOSTNAME"

# compute workers-dashboard hostname by inserting at index 1 only for preview hosts
_orig="$KUBE_INGRESS_HOSTNAME"
_first="${_orig%%.*}"      # first label (before first dot)
_rest="${_orig#*.}"        # rest of the hostname (after first dot)

if [[ "$_orig" == *preview* ]]; then
    export KUBE_INGRESS_WORKER_HOSTNAME="$_first.workers-dashboard.$_rest"
else
    export KUBE_INGRESS_WORKER_HOSTNAME="workers-dashboard.$_orig"
fi

echo "deploy :: kube ingress worker hostname - $KUBE_INGRESS_WORKER_HOSTNAME"
echo "deploy :: kube deploy id - $KUBE_DEPLOY_ID"

kube_pre_deploy_script="$KUBE_ROOT/scripts/pre-deploy.sh"
kube_post_deploy_script="$KUBE_ROOT/scripts/post-deploy.sh"
kube_parsed_labels=""

# kubernetes labels
# we convert invalid label values to 'NA'
# this breaks input on IFS
for label in $KUBE_LABELS
do
    lKey=${label%=*}
    lValue=${label#*=}

    if ! [[ $lValue =~ ^(([A-Za-z0-9][-A-Za-z0-9_.]*)?[A-Za-z0-9])?$ ]]; then
        echo "deploy :: value for label - $lKey is not valid - $lValue"
        lValue="NA"
    fi

    kube_parsed_labels+="$lKey=$lValue "
done

echo "deploy :: parsed labels - $kube_parsed_labels"

# deployment pre deploy hook
if [ -f "$kube_pre_deploy_script" ]; then
    echo "deploy :: running pre deploy hook - $kube_pre_deploy_script"
    # shellcheck disable=SC1090
    source "$kube_pre_deploy_script"
fi

# kubernetes namespace
# only created once
kubectl get namespace "$KUBE_NS" || kubectl create namespace "$KUBE_NS"

# doppler secret - allowing resources to access secrets on doppler
# see - https://docs.doppler.com/docs/kubernetes-operator
# created if does not exists, updates in place if updated
if [[ -n "$DOPPLER_TOKEN" ]]; then
    kubectl create secret generic "$DOPPLER_TOKEN_SECRET_NAME" --namespace doppler-operator-system --from-literal=serviceToken="$DOPPLER_TOKEN" \
        --save-config \
        --dry-run=client \
        -o yaml | \
    kubectl apply -f -
fi

# docker registry secret - allowing resources to access private registries
# see - https://stackoverflow.com/questions/45879498/how-can-i-update-a-secret-on-kubernetes-when-it-is-generated-from-a-file
# created if does not exists, updates in place if updated
if [[ -n "$DOCKER_USERNAME" ]]; then
    kubectl create secret docker-registry regcred --docker-server="$DOCKER_REGISTRY" --docker-username="$DOCKER_USERNAME" --docker-password="$DOCKER_PASSWORD" -n "$KUBE_NS" \
        --save-config \
        --dry-run=client \
        -o yaml | \
    kubectl apply -f -
fi

# kubernetes config (core / shared / env)
kube_core_dir="$KUBE_ROOT/core"
kube_shared_dir="$KUBE_ROOT/shared"
kube_env_dir="$KUBE_ROOT/$KUBE_ENV"

if [ -d "$kube_core_dir" ]; then
    for file in "$kube_core_dir"/*; do
        echo "deploy :: deploying from core config - $kube_core_dir/$file"
        envsubst <"$file" | kubectl apply -f -

        if [ -n "$kube_parsed_labels" ]; then
            envsubst <"$file" | kubectl label --overwrite -f - $(echo $kube_parsed_labels)
        fi
    done
fi

if [ -d "$kube_shared_dir" ]; then
    for file in "$kube_shared_dir"/*; do
        echo "deploy :: deploying from shared config - $kube_shared_dir/$file"
        envsubst <"$file" | kubectl apply -f -

        if [ -n "$kube_parsed_labels" ]; then
            envsubst <"$file" | kubectl label --overwrite -f - $(echo $kube_parsed_labels)
        fi
    done
fi

if [ -d "$kube_env_dir" ]; then
    for file in "$kube_env_dir"/*; do
        # TODO: https://github.com/jalantechnologies/github-ci/issues/77
        # Skip temporal deployment ONLY in preview
        if [[ "$KUBE_ENV" == "preview" && "$file" == *temporal-deployment.yaml ]]; then
            echo "deploy :: skipping temporal deployment in preview env - $file"
            continue
        fi

        echo "deploy :: deploying from env config - $kube_env_dir/$file"
        envsubst <"$file" | kubectl apply -f -

        if [ -n "$kube_parsed_labels" ]; then
            envsubst <"$file" | kubectl label --overwrite -f - $(echo $kube_parsed_labels)
        fi
    done
fi


# deployment post deploy hook
if [ -f "$kube_post_deploy_script" ]; then
    echo "deploy :: running post deploy hook - $kube_post_deploy_script"
    # shellcheck disable=SC1090
    source "$kube_post_deploy_script"
fi

echo "deploy :: deployment finished - $KUBE_INGRESS_HOSTNAME"
