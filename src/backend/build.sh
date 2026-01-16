#!/bin/bash
# Build script for supabase backend
source ./variables.sh

_WORKING_DIR=$(pwd)

if [ ! -d "$PROJECT_DIR" ]; then
    echo "Creating project directory at $PROJECT_DIR"
    mkdir -p "$PROJECT_DIR"
    echo "Project directory created. at $PROJECT_DIR"
else
    echo "Project directory already exists, skipping mkdir."
fi

# Create local backend folder if missing
# Tree should look like this
# ├── librebeats_api/build (output directory)
# └── librebeats_api/supabase (git clone of supabase repo)

if [ ! -d "$BUILD_DIRECTORY" ]; then
    mkdir "$BUILD_DIRECTORY"
    cd "$SUPABASE_DIR"
    cp -rf $_WORKING_DIR/supabase/* "$BUILD_DIRECTORY"
else
    echo "$BUILD_DIRECTORY already exists, skipping mkdir."
    cp -rf $_WORKING_DIR/supabase/* "$BUILD_DIRECTORY"
fi

# # # Copy the fake env vars if .env does not exist
if [ -f "$BUILD_DIRECTORY/.env" ]; then
    echo ".env file already exists, skipping copy."
else
    echo "Copying .env file."
    cp $_WORKING_DIR/supabase/.env.example "$BUILD_DIRECTORY/.env"
fi

# # # Switch to your project directory
cd "$BUILD_DIRECTORY"

# # # Pull the latest images
docker compose pull

# # # To generate and apply all secrets at once you can run: https://supabase.com/docs/guides/self-hosting/docker#quick-setup-experimental
if [ "$GENERATE_KEYS" = true ]; then
    echo "Generating new keys."
    sh $BUILD_DIRECTORY/utils/generate-keys.sh
else
    echo "Skipping key generation."
fi