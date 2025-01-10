#!/usr/bin/env bash

# Prerequisite:
# Install wave: https://docs.seqera.io/wave/cli/reference#install-the-wave-cli

CONTAINER_URL="$(wave -f Dockerfile --context .)"

# If docker is installed

if ! command -v docker &> /dev/null
then
    echo "Docker could not be found, so we cannot pull the container"
    exit
else
    echo "Pulling container: $CONTAINER_URL"
    docker pull $CONTAINER_URL
fi
