#!/bin/bash
source ./variables.sh

# Switch to your project directory
cd $BUILD_DIRECTORY

docker compose build audio migrations
docker compose up -d

#--force-recreate
