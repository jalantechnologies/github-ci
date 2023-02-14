#!/bin/bash

set -o pipefail

# requires - RENDER_TOKEN, RENDER_SERVICE_ID

deploy_wait_interval_sec=10
deploy_wait_limit_sec=$((30 * 60)) # 30 minutes

check_deployment () {
  echo "checking deployment - $1"

  deploy=$(curl -s --request GET \
       --url "https://api.render.com/v1/services/$RENDER_SERVICE_ID/deploys/$1" \
       --header "Authorization: Bearer $RENDER_TOKEN")

  deploy_status=$(echo "$deploy" | jq -r '.status')
  echo "checked deployment status - $deploy_status"

  if [ "$deploy_status" = "live" ]; then
      return 0
  else
      return 1
  fi
}

deploy=$(curl -s --request POST \
     --url "https://api.render.com/v1/services/$RENDER_SERVICE_ID/deploys" \
     --header "Authorization: Bearer $RENDER_TOKEN")

deploy_id=$(echo "$deploy" | jq -r '.id')

SECONDS=0
echo "waiting for $deploy_wait_limit_sec seconds..."

until check_deployment "$deploy_id"
do
  if [ $SECONDS -gt $deploy_wait_limit_sec ]; then
      return 1
  fi
  echo "$SECONDS seconds have elapsed..."

  sleep $deploy_wait_interval_sec
done

echo "deployment went live in $SECONDS seconds"
echo "$service_url"
