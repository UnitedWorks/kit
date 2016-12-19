set -e
# //////////////////////////////////////////////////////////////////////////////
# Variables
# //////////////////////////////////////////////////////////////////////////////
KIT_PATH="$HOME/Sites/kit"
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
  echo    # (optional) move to a new line
  if [[ $REPLY =~ ^[Nn]$ ]]
  then
    echo "Aborting"
    return 1
  fi
  echo "Running"
}

# //////////////////////////////////////////////////////////////////////////////
# Build Functions
# //////////////////////////////////////////////////////////////////////////////
function docker_compose () {
  cd "${KIT_PATH}" && docker-compose build && cd -
}

function build_api () {
  cd "${KIT_API_PATH}" && docker build -t "${API_IMAGE}:${BUILD}" . && cd -
}

function build_dashboard () {
  cd "${KIT_DASHBOARD_PATH}" && docker build -t "${DASHBOARD_IMAGE}:${BUILD}" . && cd -
}

# //////////////////////////////////////////////////////////////////////////////
# Push Functions
# //////////////////////////////////////////////////////////////////////////////
function push_api () {
  docker tag "${API_IMAGE}:${BUILD}" "${REGISTRY}/${API_REPO}:${BUILD}"
  docker push "${REGISTRY}/${API_REPO}"
}

function push_dashboard () {
  docker tag "${DASHBOARD_IMAGE}:${BUILD}" "${REGISTRY}/${DASHBOARD_REPO}:${BUILD}"
  docker push "${REGISTRY}/${DASHBOARD_REPO}"
}

# //////////////////////////////////////////////////////////////////////////////
# Task/Service Functions
# //////////////////////////////////////////////////////////////////////////////
function update_api_task () {
  cd "${KIT_PATH}" && aws ecs register-task-definition --cli-input-json file://deploy/${API_FAMILY}-task-definition.json
}

function update_api_service () {
  cd "${KIT_PATH}" && aws ecs update-service --cluster $CLUSTER --service $API_FAMILY --task-definition $API_FAMILY --desired-count $API_COUNT
}

function update_dashboard_task () {
  cd "${KIT_PATH}" && aws ecs register-task-definition --cli-input-json file://deploy/${DASHBOARD_FAMILY}-task-definition.json
}

function update_dashboard_service () {
  cd "${KIT_PATH}" && aws ecs update-service --cluster $CLUSTER --service $DASHBOARD_FAMILY --task-definition $DASHBOARD_FAMILY --desired-count $DASHBOARD_COUNT
}

# //////////////////////////////////////////////////////////////////////////////
# Database Functions
# //////////////////////////////////////////////////////////////////////////////
function migrate_production_db () {
  cd "${KIT_API_PATH}" && git stash && git checkout master && git pull origin master && npm run migrate-production && cd -
}

# //////////////////////////////////////////////////////////////////////////////
# Handle the ARGs
# //////////////////////////////////////////////////////////////////////////////
while [[ $# > 0 ]]
do
case "${1}" in
  --deploy-api)
  confirm_command
  build_api
  eval_aws
  push_api
  update_api_task
  update_api_service
  shift
  ;;
  --deploy-dashboard)
  confirm_command
  build_dashboard
  eval_aws
  push_dashboard
  update_dashboard_task
  update_dashboard_service
  shift
  ;;
  --deploy_both)
  confirm_command
  docker_compose
  eval_aws
  push_api
  update_api_task
  update_api_service
  push_dashboard
  update_dashboard_task
  update_dashboard_service
  shift
  ;;
  --migrate-production-db)
  confirm_command
  shift
  ;;
  *)
  echo "'${1}' is not a valid operation."
  ;;
esac
shift
done
