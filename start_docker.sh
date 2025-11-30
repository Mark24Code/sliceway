#!/bin/bash

# Ensure data directories exist
mkdir -p data/uploads
mkdir -p data/public
mkdir -p data/db
mkdir -p data/exports

# Build and start containers
echo "Starting Sliceway (Single Container) with Docker..."
echo "可通过环境变量自定义挂载卷路径："
echo "  UPLOADS_VOLUME PUBLIC_VOLUME DB_VOLUME EXPORTS_VOLUME"
echo "示例：UPLOADS_VOLUME=/your/path/uploads ./start_docker.sh"
docker-compose up --build -d

echo "-----------------------------------"
echo "App running at http://localhost:4567"
echo "-----------------------------------"
echo "To stop: docker-compose down"
