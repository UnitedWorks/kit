#!/bin/bash

set -e

# //////////////////////////////////////////////////////////////////////////////
# Variables
# //////////////////////////////////////////////////////////////////////////////
KIT_PATH="$PWD"
KIT_API_PATH="$KIT_PATH/kit_api"
KIT_DASHBOARD_PATH="$KIT_PATH/kit_dashboard"

REGISTRY="188711547141.dkr.ecr.us-east-1.amazonaws.com"
CLUSTER="kit_production"

BUILD="latest"

API_REPO="kit_api/api"
API_IMAGE="kit_api"
API_FAMILY="api"
API_COUNT=2

DASHBOARD_REPO="kit_dashboard/dashboard"
DASHBOARD_IMAGE="kit_dashboard"
DASHBOARD_FAMILY="dashboard"
DASHBOARD_COUNT=2

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
  stash_work
  pull_master
  docker build -t "${API_IMAGE}:${BUILD}" .
  unstash_work
  cd -
}

function build_dashboard () {
  # Stash changes, pull master, build, and then restore changes.
  cd "${KIT_DASHBOARD_PATH}"
  stash_work
  pull_master
  docker build -t "${DASHBOARD_IMAGE}:${BUILD}" .
  unstash_work
  cd -
}

# //////////////////////////////////////////////////////////////////////////////
# Push Functions
# //////////////////////////////////////////////////////////////////////////////
function push_api_image () {
  docker tag "${API_IMAGE}:${BUILD}" "${REGISTRY}/${API_REPO}:${BUILD}"
  docker push "${REGISTRY}/${API_REPO}"
}

function push_dashboard_image () {
  docker tag "${DASHBOARD_IMAGE}:${BUILD}" "${REGISTRY}/${DASHBOARD_REPO}:${BUILD}"
  docker push "${REGISTRY}/${DASHBOARD_REPO}"
}

# //////////////////////////////////////////////////////////////////////////////
# Task/Service Functions
# //////////////////////////////////////////////////////////////////////////////
function update_api_task () {
  cd "${KIT_PATH}"
  aws ecs register-task-definition --cli-input-json file://deploy/${API_FAMILY}-task-definition.json
  cd -
}

function update_api_service () {
  cd "${KIT_PATH}"
  aws ecs update-service --cluster $CLUSTER --service $API_FAMILY --task-definition $API_FAMILY --desired-count $API_COUNT
  cd -
}

function update_dashboard_task () {
  cd "${KIT_PATH}"
  aws ecs register-task-definition --cli-input-json file://deploy/${DASHBOARD_FAMILY}-task-definition.json
  cd -
}

function update_dashboard_service () {
  cd "${KIT_PATH}"
  aws ecs update-service --cluster $CLUSTER --service $DASHBOARD_FAMILY --task-definition $DASHBOARD_FAMILY --desired-count $DASHBOARD_COUNT
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
# Run
# //////////////////////////////////////////////////////////////////////////////
while [[ $# > 0 ]]
do
case "${1}" in
  --deploy-api)
  confirm_command
  build_api
  eval_aws
  push_api_image
  update_api_task
  update_api_service
  shift
  ;;
  --deploy-dashboard)
  confirm_command
  build_dashboard
  eval_aws
  push_dashboard_image
  update_dashboard_task
  update_dashboard_service
  shift
  ;;
  --deploy-application)
  confirm_command
  build_api
  build_dashboard
  eval_aws
  push_api_image
  update_api_task
  update_api_service
  push_dashboard_image
  update_dashboard_task
  update_dashboard_service
  shift
  ;;
  --deploy-frontdoor)
  confirm_command
  # Todo
  shift
  ;;
  --migrate-production-db)
  confirm_command
  # Todo
  shift
  ;;
  *)
  echo "'${1}' is not a valid operation."
  ;;
esac
shift
done
