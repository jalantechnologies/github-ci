#!/bin/bash

# requires - KUBE_ROOT, KUBE_NS, KUBE_APP, KUBE_ENV

# set defaults
KUBE_ROOT="${KUBE_ROOT:-lib/kube}"

echo "cleaning up k8"
echo "kube root - $KUBE_ROOT"
echo "kube namespace - $KUBE_NS"
echo "kube app - $KUBE_APP"
echo "kube env - $KUBE_ENV"

kube_pre_clean_script="$KUBE_ROOT/scripts/pre-clean.sh"
kube_post_clean_script="$KUBE_ROOT/scripts/post-clean.sh"

if [ -f "$kube_pre_clean_script" ]; then
  echo "running pre-clean script from - $kube_pre_clean_script"
  source "$kube_pre_clean_script"
  echo "finished running pre-clean script"
fi

kube_shared_dir="$KUBE_ROOT/shared"
kube_env_dir="$KUBE_ROOT/$KUBE_ENV"

if [ -d "$kube_shared_dir" ]; then
  echo "cleaning up from shared specifications - $kube_shared_dir"

  for file in "$kube_shared_dir"/*; do
    envsubst <"$file" | kubectl delete --ignore-not-found=true -f -
  done
fi

if [ -d "$kube_env_dir" ]; then
  echo "cleaning up from env specifications - $kube_env_dir"

  for file in "$kube_env_dir"/*; do
    envsubst <"$file" | kubectl delete --ignore-not-found=true -f -
  done
fi

if [ -f "$kube_post_clean_script" ]; then
  echo "running post-clean script from - $kube_post_clean_script"
  source "$kube_post_clean_script"
  echo "finished running post-clean script"
fi
