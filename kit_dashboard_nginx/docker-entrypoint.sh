#!/usr/bin/env bash

# Exit the script as soon as something fails.
set -e

# Forwarding name and port. Should be the name of the Docker image that is linked to nginx.
# To test locally, set to "kit_dashboard_1"
PLACEHOLDER_FORWARDING_NAME="dashboard"
PLACEHOLDER_FORWARDING_PORT="8000"

# The server_name value
# If using AWS load balancer, typically a EC2 instance's public DNS name
# If not, set to the domain name (ex: foo.com)
# To test locally, set to "localhost"
PLACEHOLDER_VHOST="$(curl http://169.254.169.254/latest/meta-data/public-hostname)"

# Default config location (set in Dockerfile)
DEFAULT_CONFIG_PATH="/etc/nginx/conf.d/default.conf"

# Replace all instances of the placeholders with the values above.
sed -i "s/PLACEHOLDER_VHOST/${PLACEHOLDER_VHOST}/g" "${DEFAULT_CONFIG_PATH}"
sed -i "s/PLACEHOLDER_FORWARDING_NAME/${PLACEHOLDER_FORWARDING_NAME}/g" "${DEFAULT_CONFIG_PATH}"
sed -i "s/PLACEHOLDER_FORWARDING_PORT/${PLACEHOLDER_FORWARDING_PORT}/g" "${DEFAULT_CONFIG_PATH}"

# Execute the CMD from the Dockerfile and pass in all of its arguments.
exec "$@"
