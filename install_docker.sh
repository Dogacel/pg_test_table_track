#!/bin/bash

set -ex

EXTENSION_NAME="pg_test_table_track"
CONTAINER_NAME=${1:-}
DB_NAME=${2:-}
POSTGRES_USER=${3:-}

echo "Checking if PostgreSQL container ($CONTAINER_NAME) is running..."
if ! docker ps --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
  echo "PostgreSQL container is not running. Exiting..."
  exit 1
fi

echo "Copying extension files to the container..."
docker cp . "$CONTAINER_NAME":/tmp/"$EXTENSION_NAME"

# Define PostgreSQL extension directory inside the container
PG_VERSION=$(docker exec -it "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$DB_NAME" -t -c "SHOW server_version_num;" | tr -d ' \n' | cut -c 1-2)
EXT_DIR="/usr/share/postgresql/${PG_VERSION}/extension"

echo "Creating extension directory inside container if it doesn't exist..."
docker exec -it "$CONTAINER_NAME" mkdir -p "$EXT_DIR"

echo "Copying extension control file..."
docker cp "./$EXTENSION_NAME.control" "$CONTAINER_NAME:$EXT_DIR/"

echo "Copying SQL files to a temporary location inside the container..."
docker cp "./sql" "$CONTAINER_NAME:/tmp/${EXTENSION_NAME}_sql"

echo "Moving SQL files to PostgreSQL extension directory..."
docker exec -it "$CONTAINER_NAME" bash -c "mv /tmp/${EXTENSION_NAME}_sql/* $EXT_DIR/ && rm -rf /tmp/${EXTENSION_NAME}_sql"

echo "Activating the extension in the database..."
docker exec -it "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$DB_NAME" -c "CREATE EXTENSION IF NOT EXISTS $EXTENSION_NAME;"

echo "Installation complete! Your PostgreSQL extension is now active."

