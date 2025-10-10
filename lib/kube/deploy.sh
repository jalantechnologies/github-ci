#!/bin/bash

echo "deploy :: starting deployment procedure"
echo "deploy :: kube root - $KUBE_ROOT"
echo "deploy :: kube namespace - $KUBE_NS"
echo "deploy :: kube app - $KUBE_APP"
echo "deploy :: kube env - $KUBE_ENV"
echo "deploy :: kube deployment image - $KUBE_DEPLOYMENT_IMAGE"
echo "deploy :: kube ingress hostname - $KUBE_INGRESS_HOSTNAME"

# Mask secrets
[ -n "$DOPPLER_TOKEN" ] && echo "::add-mask::$DOPPLER_TOKEN"
[ -n "$DOCKER_PASSWORD" ] && echo "::add-mask::$DOCKER_PASSWORD"

# Set provider-specific node affinity dynamically — only if not already set
if [[ -z "${NODE_POOL_SELECTOR_KEY:-}" ]]; then
  case "${HOSTING_PROVIDER}" in
    "DIGITAL_OCEAN")
      export NODE_POOL_SELECTOR_KEY="doks.digitalocean.com/node-pool"
      ;;
    "AWS")
      export NODE_POOL_SELECTOR_KEY="kubernetes.githubci.com/nodegroup"
      ;;
    *)
      echo "deploy :: unsupported hosting provider - $HOSTING_PROVIDER"
      exit 1
      ;;
  esac
fi

if [[ -z "${NODE_POOL_VALUE:-}" ]]; then
  case "${HOSTING_PROVIDER}" in
    "DIGITAL_OCEAN")
      if [[ "$KUBE_ENV" == "production" ]]; then
        export NODE_POOL_VALUE="platform-cluster-01-production-pool"
      else
        export NODE_POOL_VALUE="platform-cluster-01-staging-pool"
      fi
      ;;
    "AWS")
      if [[ "$KUBE_ENV" == "production" ]]; then
        export NODE_POOL_VALUE="ng-production-pool"
      else
        export NODE_POOL_VALUE="ng-preview-pool"
      fi
      ;;
  esac
fi

# Compute worker hostname
_orig="$KUBE_INGRESS_HOSTNAME"
_first="${_orig%%.*}"
_rest="${_orig#*.}"

if [[ "$_orig" == *preview* ]]; then
    export KUBE_INGRESS_WORKER_HOSTNAME="$_first.workers-dashboard.$_rest"
else
    export KUBE_INGRESS_WORKER_HOSTNAME="workers-dashboard.$_orig"
fi

echo "deploy :: kube ingress worker hostname - $KUBE_INGRESS_WORKER_HOSTNAME"
echo "deploy :: kube deploy id - $KUBE_DEPLOY_ID"

# Ensure DOPPLER_MANAGED_SECRET_NAME is set
if [[ -z "${DOPPLER_MANAGED_SECRET_NAME:-}" ]]; then
    export DOPPLER_MANAGED_SECRET_NAME="doppler-secret-$KUBE_APP"
fi

export GITHUB_SHA

kube_pre_deploy_script="$KUBE_ROOT/scripts/pre-deploy.sh"
kube_post_deploy_script="$KUBE_ROOT/scripts/post-deploy.sh"
kube_parsed_labels=""

# Sanitize labels
for label in $KUBE_LABELS; do
    lKey=${label%=*}
    lValue=${label#*=}
    safe_value=$(echo "$lValue" | sed -E 's/[^a-zA-Z0-9._-]+/-/g' | sed -E 's/^-+|-+$//g')
    if [[ -z "$safe_value" ]]; then
        safe_value="NA"
    fi
    kube_parsed_labels+="$lKey=$safe_value "
done

echo "deploy :: parsed labels - $kube_parsed_labels"

# Pre-deploy hook
if [ -f "$kube_pre_deploy_script" ]; then
    echo "deploy :: running pre deploy hook - $kube_pre_deploy_script"
    source "$kube_pre_deploy_script"
fi

# Namespace
kubectl get namespace "$KUBE_NS" > /dev/null 2>&1 || kubectl create namespace "$KUBE_NS"

# Doppler secret
if [[ -n "$DOPPLER_TOKEN" ]]; then
    printf '%s' "$DOPPLER_TOKEN" | kubectl create secret generic "$DOPPLER_TOKEN_SECRET_NAME" \
        --namespace doppler-operator-system \
        --from-file=serviceToken=/dev/stdin \
        --dry-run=client -o yaml | kubectl apply -f -
fi

# Docker registry secret
if [[ -n "$DOCKER_USERNAME" ]]; then
    jq -nc --arg u "$DOCKER_USERNAME" --arg p "$DOCKER_PASSWORD" --arg s "$DOCKER_REGISTRY" \
    '{auths:{($s):{username:$u,password:$p,auth:(($u+":"+$p)|@base64)}}}' \
    | kubectl create secret generic regcred \
        --type=kubernetes.io/dockerconfigjson \
        --from-file=.dockerconfigjson=/dev/stdin \
        -n "$KUBE_NS" --dry-run=client -o yaml | kubectl apply -f -
fi

# Define variables for substitution
SUBST_VARS='$NODE_POOL_SELECTOR_KEY,$NODE_POOL_VALUE,$KUBE_NS,$KUBE_APP,$KUBE_ENV,$KUBE_DEPLOYMENT_IMAGE,$KUBE_INGRESS_HOSTNAME,$KUBE_INGRESS_WORKER_HOSTNAME,$KUBE_DEPLOY_ID,$GITHUB_SHA,$DOPPLER_MANAGED_SECRET_NAME'

# Deploy from core, shared, env
for dir in "$KUBE_ROOT/core" "$KUBE_ROOT/shared" "$KUBE_ROOT/$KUBE_ENV"; do
    if [[ -d "$dir" ]]; then
        for file in "$dir"/*; do
            [[ -f "$file" ]] || continue
            echo "deploy :: deploying from $dir - $file"
            rendered=$(envsubst "$SUBST_VARS" < "$file")
            echo "$rendered" | kubectl apply -f -
            if [[ -n "$kube_parsed_labels" ]]; then
                echo "$rendered" | kubectl label --overwrite -f - $kube_parsed_labels
            fi
        done
    fi
done

# Post-deploy hook
if [ -f "$kube_post_deploy_script" ]; then
    echo "deploy :: running post deploy hook - $kube_post_deploy_script"
    source "$kube_post_deploy_script"
fi

echo "deploy :: deployment finished - $KUBE_INGRESS_HOSTNAME"
