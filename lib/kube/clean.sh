#!/bin/bash
set -e

# requires - KUBE_ROOT, KUBE_NS, KUBE_APP, KUBE_ENV

echo "clean :: starting clean up procedure"
echo "clean :: kube root - $KUBE_ROOT"
echo "clean :: kube namespace - $KUBE_NS"
echo "clean :: kube app - $KUBE_APP"
echo "clean :: kube env - $KUBE_ENV"


# Default to DIGITAL_OCEAN for backward compatibility
HOSTING_PROVIDER1=${HOSTING_PROVIDER1:-DIGITAL_OCEAN}

export NODE_POOL_SELECTOR_KEY=""
export NODE_POOL_VALUE=""

case "$HOSTING_PROVIDER1" in
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
        echo "clean :: ❌ Unknown HOSTING_PROVIDER1 value: $HOSTING_PROVIDER1"
        echo "clean :: valid values are [DIGITAL_OCEAN, AWS]"
        exit 1
        ;;
esac



kube_pre_clean_script="$KUBE_ROOT/scripts/pre-clean.sh"
kube_post_clean_script="$KUBE_ROOT/scripts/post-clean.sh"

# Pre-clean hook
if [ -f "$kube_pre_clean_script" ]; then
    echo "clean :: running pre clean up hook - $kube_pre_clean_script"
    source "$kube_pre_clean_script"
else
    echo "clean :: no pre-clean hook found, skipping."
fi



kube_shared_dir="$KUBE_ROOT/shared"
kube_env_dir="$KUBE_ROOT/$KUBE_ENV"

# Delete Shared Resources
if [ -d "$kube_shared_dir" ]; then
    echo "clean :: deleting shared resources from → $kube_shared_dir"
    for file in "$kube_shared_dir"/*; do
        [ -f "$file" ] || continue
        echo "clean :: deleting → $file"
        envsubst < "$file" | kubectl delete -n "$KUBE_NS" --ignore-not-found=true -f - || true
    done
else
    echo "clean :: no shared config found."
fi

# Delete Environment-Specific Resources
if [ -d "$kube_env_dir" ]; then
    echo "clean :: deleting environment resources from → $kube_env_dir"
    for file in "$kube_env_dir"/*; do
        [ -f "$file" ] || continue
        echo "clean :: deleting → $file"
        envsubst < "$file" | kubectl delete -n "$KUBE_NS" --ignore-not-found=true -f - || true
    done
else
    echo "clean :: no environment config found."
fi

# Post-clean hook
if [ -f "$kube_post_clean_script" ]; then
    echo "clean :: running post-clean hook → $kube_post_clean_script"
    source "$kube_post_clean_script"
else
    echo "clean :: no post-clean hook found, skipping."
fi

echo "clean :: ✅ cleanup procedure finished successfully."