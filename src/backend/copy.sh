#!/bin/bash
# Build script for supabase backend
source ./variables.sh

_WORKING_DIR=$(pwd)

cp -rf $_WORKING_DIR/supabase/* "$BUILD_DIRECTORY"

# # # Switch to your project directory
cd "$BUILD_DIRECTORY"

docker compose build migrations
docker compose up migrations --force-recreate