#!/bin/bash

# Ensure data directories exist
mkdir -p data/uploads
mkdir -p data/public
mkdir -p data/db
mkdir -p data/exports

# Build and start containers
echo "Starting Sliceway (Single Container) with Docker..."
docker-compose up --build -d

echo "-----------------------------------"
echo "App running at http://localhost:4567"
echo "-----------------------------------"
echo "To stop: docker-compose down"
