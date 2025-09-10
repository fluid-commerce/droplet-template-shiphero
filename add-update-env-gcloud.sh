#!/bin/bash

SERVICE=fluid-droplet-shiphero
SERVICE_JOBS_MIGRATIONS=fluid-droplet-shiphero-migrations
SERVICE_RAILS_JOBS_CONSOLE=fluid-droplet-shiphero-jobs-console
IMAGE_URL=europe-west1-docker.pkg.dev/fluid-417204/fluid-droplets/fluid-droplet-shiphero-rails/web:latest

# Variables array - add your variables here
VARS=(
  "EXAMPLE_VARIABLE=example_value"
  "EXAMPLE_VARIABLE2=example_value2"
  "ANOTHER_VAR=another_value"
  # Add more variables as needed
)

# Build the environment variables arguments for Cloud Run
CLOUD_RUN_ENV_ARGS=""
for var in "${VARS[@]}"; do
  CLOUD_RUN_ENV_ARGS="$CLOUD_RUN_ENV_ARGS --update-env-vars $var"
done

# Build the environment variables arguments for Compute Engine
COMPUTE_ENV_ARGS=""
for var in "${VARS[@]}"; do
  COMPUTE_ENV_ARGS="$COMPUTE_ENV_ARGS --container-env=$var"
done

# Update the environment variables for the service cloud run web Cloud Run migrations
gcloud run jobs update $SERVICE_JOBS_MIGRATIONS --region=europe-west1 --image $IMAGE_URL $CLOUD_RUN_ENV_ARGS

# Update the environment variables for the service cloud run web
echo "Updating Cloud Run service: $SERVICE"
gcloud run services update $SERVICE --region=europe-west1 --image $IMAGE_URL $CLOUD_RUN_ENV_ARGS

# Update the environment variables for the service rails jobs console Compute Engine
echo "Updating Compute Engine instance: $SERVICE_RAILS_JOBS_CONSOLE"
gcloud compute instances update-container $SERVICE_RAILS_JOBS_CONSOLE --zone=europe-west1-b $COMPUTE_ENV_ARGS