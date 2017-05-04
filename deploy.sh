#!/bin/bash

set -e

# //////////////////////////////////////////////////////////////////////////////
# Variables
# //////////////////////////////////////////////////////////////////////////////
KIT_PATH="$PWD"
KIT_API_PATH="$KIT_PATH/kit_api"
KIT_API_NGINX_PATH="$KIT_PATH/kit_api_nginx"
KIT_DASHBOARD_PATH="$KIT_PATH/kit_dashboard"
KIT_DASHBOARD_NGINX_PATH="$KIT_PATH/kit_dashboard_nginx"
KIT_FRONTDOOR_PATH="$KIT_PATH/kit_frontdoor"

REGISTRY="188711547141.dkr.ecr.us-east-1.amazonaws.com"
CLUSTER="kit_production"

BUILD="latest"

API_REPO="kit_api/api"
API_IMAGE="kit_api"
API_FAMILY="api"

API_NGINX_REPO="kit_api/nginx"
API_NGINX_IMAGE="kit_api_nginx"

DASHBOARD_REPO="kit_dashboard/dashboard"
DASHBOARD_IMAGE="kit_dashboard"
DASHBOARD_FAMILY="dashboard"

DASHBOARD_NGINX_REPO="kit_dashboard/nginx"
DASHBOARD_NGINX_IMAGE="kit_dashboard_nginx"

FRONTDOOR_BUCKET="kit.community"
FRONTDOOR_CLOUDFRONT_DIST_ID="E1BJ6HA10GA3H1"

# //////////////////////////////////////////////////////////////////////////////
# Common Functions
# //////////////////////////////////////////////////////////////////////////////
function eval_aws () {
  eval "$(aws ecr get-login)"
}

function confirm_command () {
  read -p "Are you sure? [y/n] " -n 1 -r
  echo  # move to a new line
  if [[ $REPLY =~ ^[Yy]$ ]]
  then
    echo "Running"
  else
    echo "Aborting"
    return 1
  fi
}

# //////////////////////////////////////////////////////////////////////////////
# Build Functions
# //////////////////////////////////////////////////////////////////////////////

function stash_work () {
  STARTING_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  git stash
}

function pull_master () {
  if [[ $STARTING_BRANCH != "master" ]]
  then
    git checkout master
  fi
  git pull origin master
}

function unstash_work () {
  if [[ $STARTING_BRANCH != "master" ]]
  then
    git checkout $STARTING_BRANCH
    git stash apply stash@{0}
  fi
}

function build_api () {
  # Stash changes, pull master, build, and then restore changes.
  cd "${KIT_API_PATH}"
  if [[ $option == "master" ]]
  then
    stash_work
    pull_master
  fi
  docker build -t "${API_IMAGE}:${BUILD}" .
  if [[ $option == "master" ]]
  then
    unstash_work
  fi
  cd -
}

function build_api_nginx () {
  cd "${KIT_API_NGINX_PATH}"
  docker build -t "${API_NGINX_IMAGE}:${BUILD}" .
  cd -
}

function build_dashboard () {
  # Stash changes, pull master, build, and then restore changes.
  cd "${KIT_DASHBOARD_PATH}"
  if [[ $option == "master" ]]
  then
    stash_work
    pull_master
  fi
  docker build -t "${DASHBOARD_IMAGE}:${BUILD}" .
  if [[ $option == "master" ]]
  then
    unstash_work
  fi
  cd -
}

function build_dashboard_nginx () {
  cd "${KIT_DASHBOARD_NGINX_PATH}"
  docker build -t "${DASHBOARD_NGINX_IMAGE}:${BUILD}" .
  cd -
}

# //////////////////////////////////////////////////////////////////////////////
# Push Functions
# //////////////////////////////////////////////////////////////////////////////
function push_api_image () {
  docker tag "${API_IMAGE}:${BUILD}" "${REGISTRY}/${API_REPO}:${BUILD}"
  docker push "${REGISTRY}/${API_REPO}"
}

function push_api_nginx_image () {
  docker tag "${API_NGINX_IMAGE}:${BUILD}" "${REGISTRY}/${API_NGINX_REPO}:${BUILD}"
  docker push "${REGISTRY}/${API_NGINX_REPO}"
}

function push_dashboard_image () {
  docker tag "${DASHBOARD_IMAGE}:${BUILD}" "${REGISTRY}/${DASHBOARD_REPO}:${BUILD}"
  docker push "${REGISTRY}/${DASHBOARD_REPO}"
}

function push_dashboard_nginx_image () {
  docker tag "${DASHBOARD_NGINX_IMAGE}:${BUILD}" "${REGISTRY}/${DASHBOARD_NGINX_REPO}:${BUILD}"
  docker push "${REGISTRY}/${DASHBOARD_NGINX_REPO}"
}

function push_frontdoor() {
  aws s3 sync --acl public-read --sse --delete ${KIT_FRONTDOOR_PATH} s3://${FRONTDOOR_BUCKET}
  aws configure set preview.cloudfront true
  aws cloudfront create-invalidation --distribution-id ${FRONTDOOR_CLOUDFRONT_DIST_ID} --paths "/*"
}

# //////////////////////////////////////////////////////////////////////////////
# Task/Service Functions
# //////////////////////////////////////////////////////////////////////////////
function update_api_task () {
  cd "${KIT_PATH}"
  aws ecs register-task-definition --cli-input-json file://tools/${API_FAMILY}-task-definition.json
  cd -
}

function update_api_service () {
  cd "${KIT_PATH}"
  aws ecs update-service --cluster $CLUSTER --service $API_FAMILY --task-definition $API_FAMILY
  cd -
}

function update_dashboard_task () {
  cd "${KIT_PATH}"
  aws ecs register-task-definition --cli-input-json file://tools/${DASHBOARD_FAMILY}-task-definition.json
  cd -
}

function update_dashboard_service () {
  cd "${KIT_PATH}"
  aws ecs update-service --cluster $CLUSTER --service $DASHBOARD_FAMILY --task-definition $DASHBOARD_FAMILY
  cd -
}

# //////////////////////////////////////////////////////////////////////////////
# Database Functions
# //////////////////////////////////////////////////////////////////////////////
function migrate_production_db () {
  cd "${KIT_API_PATH}"
  stash_work
  pull_master
  npm run migrate-production
  unstash_work
  cd -
}

# //////////////////////////////////////////////////////////////////////////////
# Test Functions
# //////////////////////////////////////////////////////////////////////////////
function test_api () {
  cd "${KIT_API_PATH}"
  npm test
  cd -
}

function test_dashboard () {
  cd "${KIT_DASHBOARD_PATH}"
  npm test
  cd -
}

# //////////////////////////////////////////////////////////////////////////////
# Run
# //////////////////////////////////////////////////////////////////////////////
while [[ $# > 0 ]]
do
  command=$1
  option=$2
  case "${command}" in
    --deploy-api)
    confirm_command
    test_api
    build_api $option
    eval_aws
    push_api_image
    update_api_task
    update_api_service
    shift
    ;;
    --deploy-api-nginx)
    confirm_command
    build_api_nginx
    eval_aws
    push_api_nginx_image
    update_api_task
    update_api_service
    shift
    ;;
    --deploy-dashboard)
    test_dashboard
    confirm_command
    build_dashboard $option
    eval_aws
    push_dashboard_image
    update_dashboard_task
    update_dashboard_service
    shift
    ;;
    --deploy-dashboard-nginx)
    confirm_command
    build_dashboard_nginx
    eval_aws
    push_dashboard_nginx_image
    update_dashboard_task
    update_dashboard_service
    shift
    ;;
    --deploy-frontdoor)
    confirm_command
    push_frontdoor
    shift
    ;;
    *)
    echo "'${1}' is not a valid operation."
    ;;
esac
shift
done
