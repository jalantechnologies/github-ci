#!/bin/bash
set -e

# requires - KUBE_ROOT, KUBE_NS, KUBE_APP, KUBE_ENV

echo "clean :: starting clean up procedure"
echo "clean :: kube root - $KUBE_ROOT"
echo "clean :: kube namespace - $KUBE_NS"
echo "clean :: kube app - $KUBE_APP"
echo "clean :: kube env - $KUBE_ENV"

# provider-specific node selector configuration
# set default values for backward compatibility
export NODE_POOL_SELECTOR_KEY=""
export NODE_POOL_VALUE=""

case "$HOSTING_PROVIDER" in
    "DIGITAL_OCEAN")
        export NODE_POOL_SELECTOR_KEY="doks.digitalocean.com/node-pool"
        if [[ "$KUBE_ENV" == "production" ]]; then
            export NODE_POOL_VALUE="platform-cluster-01-production-pool"
        else
            export NODE_POOL_VALUE="platform-cluster-01-staging-pool"
        fi
        echo "clean :: using DigitalOcean node selector - $NODE_POOL_SELECTOR_KEY=$NODE_POOL_VALUE"
        ;;
    "AWS")
        export NODE_POOL_SELECTOR_KEY="kubernetes.githubci.com/nodegroup"
        if [[ "$KUBE_ENV" == "production" ]]; then
            export NODE_POOL_VALUE="aws-production-pool"
        else
            export NODE_POOL_VALUE="aws-preview-pool"
        fi
        echo "clean :: using AWS node selector - $NODE_POOL_SELECTOR_KEY=$NODE_POOL_VALUE"
        ;;
    *)
        echo "clean :: warning - unknown or unset HOSTING_PROVIDER: $HOSTING_PROVIDER"
        echo "clean :: node selectors will be empty - cleanup may not work correctly"
        ;;
esac

kube_pre_clean_script="$KUBE_ROOT/scripts/pre-clean.sh"
kube_post_clean_script="$KUBE_ROOT/scripts/post-clean.sh"

# deployment pre clean hook
if [ -f "$kube_pre_clean_script" ]; then
    echo "clean :: running pre clean up hook - $kube_pre_clean_script"
    source "$kube_pre_clean_script"
else
    echo "clean :: No pre-clean hook found, skipping."
fi

# --- Define Directories ---
kube_shared_dir="$KUBE_ROOT/shared"
kube_env_dir="$KUBE_ROOT/$KUBE_ENV"

# --- Delete Shared Resources ---
if [ -d "$kube_shared_dir" ]; then
    echo "clean :: Deleting shared resources from → $kube_shared_dir"
    for file in "$kube_shared_dir"/*; do
        [ -f "$file" ] || continue
        echo "clean :: deleting → $file"
        envsubst < "$file" | kubectl delete -n "$KUBE_NS" --ignore-not-found=true -f - || true
    done
else
    echo "clean :: No shared config found."
fi

# --- Delete Environment-Specific Resources ---
if [ -d "$kube_env_dir" ]; then
    echo "clean :: Deleting environment resources from → $kube_env_dir"
    for file in "$kube_env_dir"/*; do
        [ -f "$file" ] || continue
        echo "clean :: deleting → $file"
        envsubst < "$file" | kubectl delete -n "$KUBE_NS" --ignore-not-found=true -f - || true
    done
else
    echo "clean :: No environment config found."
fi

# --- Run Post-Clean Hook ---
if [ -f "$kube_post_clean_script" ]; then
    echo "clean :: Running post-clean hook → $kube_post_clean_script"
    source "$kube_post_clean_script"
else
    echo "clean :: No post-clean hook found, skipping."
fi

echo "clean :: cleanup procedure finished successfully."