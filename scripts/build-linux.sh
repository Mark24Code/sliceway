#!/bin/bash
# 使用 Docker 构建 Linux 版本的脚本

set -e

echo ">>> 使用 Docker 构建 Linux AMD64 版本..."

# 创建临时容器
CONTAINER_ID=$(docker create $(docker build -q -f Dockerfile.build --target backend-builder .))

# 从容器复制二进制文件
mkdir -p build
docker cp $CONTAINER_ID:/output/server-linux-amd64 ./build/

# 删除临时容器
docker rm $CONTAINER_ID

echo "✓ Linux 版本构建完成: ./build/server-linux-amd64"
ls -lh ./build/server-linux-amd64
