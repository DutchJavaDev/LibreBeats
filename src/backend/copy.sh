#!/bin/bash
# restarts the migratrions service to apply new changes
source ./variables.sh
_WORKING_DIR=$(pwd)

cp -rf $_WORKING_DIR/supabase/* "$BUILD_DIRECTORY"

# # # Switch to your project directory
cd "$BUILD_DIRECTORY/service/migration" || exit 1

docker compose build migrations
docker compose up migrations -d --force-recreate