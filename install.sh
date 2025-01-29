#!/bin/bash

set -e

echo "Installing pg_test_table_track..."

# Ensure PostgreSQL is installed
if ! command -v pg_config &> /dev/null; then
    echo "Error: PostgreSQL is not installed or pg_config is missing."
    exit 1
fi

# Clone repo
git clone https://github.com/dogacel/pg_test_table_track.git
cd pg_test_table_track

# Build and install
make
sudo make install

# Verify installation
psql -d your_database -c "CREATE EXTENSION pg_test_table_track;"

echo "Installation complete!"
