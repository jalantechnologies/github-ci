#!/bin/bash

# Requires: kubectl
# Environment Variables:
# Mandatory: KUBE_ROOT, KUBE_NS, KUBE_APP, KUBE_ENV, KUBE_DEPLOYMENT_IMAGE, KUBE_INGRESS_HOSTNAME
# Optional: DOCKER_REGISTRY, DOCKER_USERNAME, DOCKER_PASSWORD, DOPPLER_TOKEN, DOPPLER_TOKEN_SECRET_NAME, DOPPLER_MANAGED_SECRET_NAME, KUBE_LABELS

# Enable debug mode if DEBUG is set to true
DEBUG=${DEBUG:-false}
if [ "$DEBUG" = true ]; then
    set -x
fi

# Function to log sensitive data safely
safe_log() {
    local message=$1
    echo "$message" | sed -E "s/(DOCKER_PASSWORD=|DOPPLER_TOKEN=)[^ ]+/\1[MASKED]/g"
}

# Validate required environment variables
REQUIRED_VARS=(KUBE_ROOT KUBE_NS KUBE_APP KUBE_ENV KUBE_DEPLOYMENT_IMAGE KUBE_INGRESS_HOSTNAME)
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        echo "deploy :: ERROR - Missing required environment variable: $var"
        exit 1
    fi
done

safe_log "deploy :: Starting deployment with namespace=$KUBE_NS, app=$KUBE_APP, env=$KUBE_ENV, image=$KUBE_DEPLOYMENT_IMAGE"

kube_pre_deploy_script="$KUBE_ROOT/scripts/pre-deploy.sh"
kube_post_deploy_script="$KUBE_ROOT/scripts/post-deploy.sh"
kube_parsed_labels=""

# Parse and validate Kubernetes labels
for label in $KUBE_LABELS; do
    lKey="${label%=*}"
    lValue="${label#*=}"
    if ! [[ $lValue =~ ^(([A-Za-z0-9][-A-Za-z0-9_.]*)?[A-Za-z0-9])?$ ]]; then
        echo "deploy :: WARNING - Invalid label value for $lKey, setting to 'NA'"
        lValue="NA"
    fi
    kube_parsed_labels+="$lKey=$lValue "
done

# Run pre-deployment script if available
if [ -f "$kube_pre_deploy_script" ]; then
    safe_log "deploy :: Running pre-deploy script - $kube_pre_deploy_script"
    if ! source "$kube_pre_deploy_script"; then
        echo "deploy :: ERROR - Pre-deploy script failed"
        exit 1
    fi
fi

# Ensure Kubernetes namespace exists
if ! kubectl get namespace "$KUBE_NS" > /dev/null 2>&1; then
    if ! kubectl create namespace "$KUBE_NS"; then
        echo "deploy :: ERROR - Failed to create namespace $KUBE_NS"
        exit 1
    fi
fi

# Create or update Doppler secret
if [[ -n "$DOPPLER_TOKEN" ]]; then
    safe_log "deploy :: Creating Doppler token secret"
    if ! kubectl create secret generic "$DOPPLER_TOKEN_SECRET_NAME" \
        --namespace doppler-operator-system \
        --from-literal=serviceToken="$DOPPLER_TOKEN" \
        --save-config --dry-run=client -o yaml | kubectl apply -f -; then
        echo "deploy :: ERROR - Failed to create/update Doppler secret"
        exit 1
    fi
fi

# Create or update Docker registry secret
if [[ -n "$DOCKER_USERNAME" && -n "$DOCKER_PASSWORD" ]]; then
    safe_log "deploy :: Creating Docker registry secret"
    if kubectl get secret regcred -n "$KUBE_NS" > /dev/null 2>&1; then
        kubectl delete secret regcred -n "$KUBE_NS"
    fi
    if ! kubectl create secret docker-registry regcred \
        --docker-server="$DOCKER_REGISTRY" \
        --docker-username="$DOCKER_USERNAME" \
        --docker-password="$DOCKER_PASSWORD" \
        -n "$KUBE_NS"; then
        echo "deploy :: ERROR - Failed to create Docker registry secret"
        exit 1
    fi
fi

# Apply Kubernetes configurations
deploy_configs() {
    local config_dir=$1
    if [ -d "$config_dir" ]; then
        for file in "$config_dir"/*; do
            echo "deploy :: Applying configuration from $file"
            if ! envsubst <"$file" | kubectl apply -f -; then
                echo "deploy :: ERROR - Failed to apply configuration $file"
                exit 1
            fi
            if [ -n "$kube_parsed_labels" ]; then
                if ! kubectl label --overwrite -f - $(echo $kube_parsed_labels); then
                    echo "deploy :: ERROR - Failed to apply labels to $file"
                    exit 1
                fi
            fi
        done
    fi
}

deploy_configs "$KUBE_ROOT/core"
deploy_configs "$KUBE_ROOT/shared"
deploy_configs "$KUBE_ROOT/$KUBE_ENV"

# Run post-deployment script if available
if [ -f "$kube_post_deploy_script" ]; then
    safe_log "deploy :: Running post-deploy script - $kube_post_deploy_script"
    if ! source "$kube_post_deploy_script"; then
        echo "deploy :: ERROR - Post-deploy script failed"
        exit 1
    fi
fi

echo "deploy :: Deployment completed successfully for $KUBE_INGRESS_HOSTNAME"

