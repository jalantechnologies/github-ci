#!/bin/bash

# requires - KUBE_ROOT, KUBE_NS, KUBE_APP, KUBE_ENV

echo "clean :: starting clean up procedure"
echo "clean :: kube root - $KUBE_ROOT"
echo "clean :: kube namespace - $KUBE_NS"
echo "clean :: kube app - $KUBE_APP"
echo "clean :: kube env - $KUBE_ENV"

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
        # TODO: https://github.com/jalantechnologies/github-ci/issues/77
        if [[ "$KUBE_ENV" == "preview" && "$file" == *temporal-deployment.yaml ]]; then
            echo "clean :: skipping temporal cleanup in preview env - $file"
            continue
        fi
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
