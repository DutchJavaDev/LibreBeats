#!/bin/bash
source ./variables.sh

# stop the backend services

cd $BUILD_DIRECTORY
docker compose down