#!/bin/bash

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
fi

# kubernetes config (shared / env)
kube_shared_dir="$KUBE_ROOT/shared"
kube_env_dir="$KUBE_ROOT/$KUBE_ENV"

if [ -d "$kube_shared_dir" ]; then
    for file in "$kube_shared_dir"/*; do
        echo "clean :: cleaning from shared config - $kube_shared_dir/$file"
        envsubst <"$file" | kubectl delete --ignore-not-found=true -f -
    done
fi

if [ -d "$kube_env_dir" ]; then
    for file in "$kube_env_dir"/*; do
        echo "clean :: cleaning from env config - $kube_env_dir/$file"
        envsubst <"$file" | kubectl delete --ignore-not-found=true -f -
    done
fi


# deployment post clean hook
if [ -f "$kube_post_clean_script" ]; then
    echo "clean :: running post clean up hook - $kube_post_clean_script"
    source "$kube_post_clean_script"
fi

echo "clean :: clean up procedure finished"
