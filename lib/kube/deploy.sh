#!/bin/bash

# requires - kubectl
# requires - KUBE_ROOT, KUBE_NS, KUBE_APP, KUBE_ENV, KUBE_DEPLOYMENT_IMAGE, KUBE_INGRESS_HOSTNAME
# requires - DOCKER_REGISTRY, DOCKER_USERNAME, DOCKER_PASSWORD
# optional - DOPPLER_TOKEN, DOPPLER_TOKEN_SECRET_NAME, DOPPLER_MANAGED_SECRET_NAME, KUBE_LABELS

echo "deploying to k8"
echo "kube namespace - $KUBE_NS"
echo "kube app - $KUBE_APP"
echo "kube env - $KUBE_ENV"
echo "kube deployment image - $KUBE_DEPLOYMENT_IMAGE"
echo "kube ingress hostname - $KUBE_INGRESS_HOSTNAME"

kube_pre_deploy_script="$KUBE_ROOT/scripts/pre-deploy.sh"
kube_post_deploy_script="$KUBE_ROOT/scripts/post-deploy.sh"

if [ -f "$kube_pre_deploy_script" ]; then
    source "$kube_pre_deploy_script"
fi

# setup kube namespace for the app
kubectl get namespace "$KUBE_NS" || kubectl create namespace "$KUBE_NS"

if [[ -n "$DOPPLER_TOKEN" ]]; then
    # create secrets which will be consumed by the deployment using environment variables
    # see - https://docs.doppler.com/docs/kubernetes-operator

    kubectl create secret generic "$DOPPLER_TOKEN_SECRET_NAME" \
        --namespace doppler-operator-system \
        --from-literal=serviceToken="$DOPPLER_TOKEN" || true
fi

# create secret for accessing docker images from configured docker registry
# the secret name is 'regcred' and deployments can be configured to use the following secret to pull docker images
# important - secret might already exist and following will throw an error in that case, handle accordingly
kubectl create secret docker-registry regcred --docker-server="$DOCKER_REGISTRY" --docker-username="$DOCKER_USERNAME" --docker-password="$DOCKER_PASSWORD" -n "$KUBE_NS" \
    --save-config \
    --dry-run=client \
    -o yaml | \
kubectl apply -f -

# apply kube config (core / shared / env)

kube_core_dir="$KUBE_ROOT/core"
kube_shared_dir="$KUBE_ROOT/shared"
kube_env_dir="$KUBE_ROOT/$KUBE_ENV"

if [ -d "$kube_core_dir" ]; then
    for file in "$kube_core_dir"/*; do
        envsubst <"$file" | kubectl apply -f -

        if [ -n "$KUBE_LABELS" ]; then
            envsubst <"$file" | kubectl label --overwrite -f - $(echo $KUBE_LABELS)
        fi
    done
fi

if [ -d "$kube_shared_dir" ]; then
    for file in "$kube_shared_dir"/*; do
        envsubst <"$file" | kubectl apply -f -

        if [ -n "$KUBE_LABELS" ]; then
            envsubst <"$file" | kubectl label --overwrite -f - $(echo $KUBE_LABELS)
        fi
    done
fi

if [ -d "$kube_env_dir" ]; then
    for file in "$kube_env_dir"/*; do
        envsubst <"$file" | kubectl apply -f -

        if [ -n "$KUBE_LABELS" ]; then
            envsubst <"$file" | kubectl label --overwrite -f - $(echo $KUBE_LABELS)
        fi
    done
fi

if [ -f "$kube_post_deploy_script" ]; then
    source "$kube_post_deploy_script"
fi

echo "deployed to - https://$KUBE_INGRESS_HOSTNAME"
