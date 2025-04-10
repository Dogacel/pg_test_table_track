#!/bin/bash


set -e

EXTENSION_NAME="pg_test_table_track"

# Help function
print_help() {
  echo "Usage: $0 <container_name> <db_name> <postgres_user>"
  echo ""
  echo "Arguments:"
  echo "  container_name   Name of the running PostgreSQL Docker container"
  echo "  db_name          Name of the PostgreSQL database"
  echo "  postgres_user    PostgreSQL user with necessary privileges"
  echo ""
  echo "Example:"
  echo "  $0 my_pg_container mydatabase postgres"
  exit 1
}

# Check if help is requested or arguments are missing
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  print_help
fi

if [ $# -ne 3 ]; then
  echo "Error: Missing arguments."
  print_help
fi

CONTAINER_NAME="$1"
DB_NAME="$2"
POSTGRES_USER="$3"

# set -x

echo "Checking if PostgreSQL container ($CONTAINER_NAME) is running..."
if ! docker ps --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
  echo "PostgreSQL container is not running. Exiting..."
  exit 1
fi

echo "Copying extension files to the container..."
docker cp "./$EXTENSION_NAME.control" "$CONTAINER_NAME:/tmp/$EXTENSION_NAME.control"
docker cp ./sql "$CONTAINER_NAME:/tmp/${EXTENSION_NAME}_sql"

# Define PostgreSQL extension directory inside the container
PG_VERSION=$(docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$DB_NAME" -t -c "SHOW server_version_num;" | tr -d ' \n' | cut -c 1-2)
EXT_DIR="/usr/share/postgresql/${PG_VERSION}/extension"

echo "Creating extension directory inside container if it doesn't exist..."
docker exec "$CONTAINER_NAME" mkdir -p "$EXT_DIR"

echo "Copying extension control file..."
docker cp "./$EXTENSION_NAME.control" "$CONTAINER_NAME:$EXT_DIR/"

echo "Copying SQL files to a temporary location inside the container..."
docker cp "./sql" "$CONTAINER_NAME:/tmp/${EXTENSION_NAME}_sql"

echo "Moving SQL files to PostgreSQL extension directory..."
docker exec "$CONTAINER_NAME" bash -c "mv /tmp/${EXTENSION_NAME}_sql/* $EXT_DIR/ && rm -rf /tmp/${EXTENSION_NAME}_sql"

echo "Activating the extension in the database..."
docker exec "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$DB_NAME" -c "CREATE EXTENSION IF NOT EXISTS $EXTENSION_NAME;"

echo "Installation complete! Your PostgreSQL extension is now active."

