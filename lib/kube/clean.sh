#!/bin/bash

# requires - KUBE_ROOT, KUBE_NS, KUBE_APP, KUBE_ENV

echo "clean :: starting clean up procedure"
echo "clean :: kube root - $KUBE_ROOT"
echo "clean :: kube namespace - $KUBE_NS"
echo "clean :: kube app - $KUBE_APP"
echo "clean :: kube env - $KUBE_ENV"

# Set provider-specific node affinity dynamically for cleanup
case "${HOSTING_PROVIDER}" in
  "DIGITAL_OCEAN")
    export NODE_POOL_SELECTOR_KEY="doks.digitalocean.com/node-pool"
    if [[ "$KUBE_ENV" == "production" ]]; then
      export NODE_POOL_VALUE="platform-cluster-01-production-pool"
    else
      export NODE_POOL_VALUE="platform-cluster-01-staging-pool"
    fi
    ;;
  "AWS")
    export NODE_POOL_SELECTOR_KEY="kubernetes.githubci.com/nodegroup"
    if [[ "$KUBE_ENV" == "production" ]]; then
      export NODE_POOL_VALUE="ng-production-pool"
    else
      export NODE_POOL_VALUE="ng-preview-pool"
    fi
    ;;
  *)
    echo "clean :: unsupported hosting provider - $HOSTING_PROVIDER"
    exit 1
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

# Define the list of variables to substitute
SUBST_VARS='$NODE_POOL_SELECTOR_KEY,$NODE_POOL_VALUE,$KUBE_NS,$KUBE_APP,$KUBE_ENV,$KUBE_DEPLOYMENT_IMAGE,$KUBE_INGRESS_HOSTNAME,$KUBE_INGRESS_WORKER_HOSTNAME,$KUBE_DEPLOY_ID'

if [ -d "$kube_shared_dir" ]; then
    for file in "$kube_shared_dir"/*; do
        echo "clean :: cleaning from shared config - $file"
        envsubst "$SUBST_VARS" < "$file" | kubectl delete --ignore-not-found=true -f -
    done
fi

if [ -d "$kube_env_dir" ]; then
    for file in "$kube_env_dir"/*; do
        echo "clean :: cleaning from env config - $file"
        envsubst "$SUBST_VARS" < "$file" | kubectl delete --ignore-not-found=true -f -
    done
fi


# deployment post clean hook
if [ -f "$kube_post_clean_script" ]; then
    echo "clean :: running post clean up hook - $kube_post_clean_script"
    source "$kube_post_clean_script"
fi

echo "clean :: clean up procedure finished"
