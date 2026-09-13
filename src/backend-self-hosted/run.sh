#!/bin/bash
source ./variables.sh

# Switch to your project directory
cd $BUILD_DIRECTORY

docker compose build audio
docker compose build migrations
docker compose up -d

#--force-recreate
