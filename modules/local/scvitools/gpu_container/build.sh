#!/usr/bin/env bash

# Prerequisite:
# Install wave: https://docs.seqera.io/wave/cli/reference#install-the-wave-cli

PLATFORM_TOKEN=$1

if [ -z "$PLATFORM_TOKEN" ]; then
    echo "Please provide a platform token, as the build time exceeds the 15 minutes in the free tier"
    exit
fi

CONTAINER_URL="$(wave -f Dockerfile --context . --tower-token $PLATFORM_TOKEN)"

# If docker is installed

if ! command -v docker &> /dev/null
then
    echo "Docker could not be found, so we cannot pull the container"
    exit
else
    echo "Pulling container: $CONTAINER_URL"
    docker pull $CONTAINER_URL
fi
