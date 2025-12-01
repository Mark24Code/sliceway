# 1. 创建并激活新的构建器（使用 docker-container 驱动）
docker buildx create --name multiarch-builder --driver docker-container --use
# 2. 启动构建器
docker buildx inspect --bootstrap
# 3. 查看构建器状态
docker buildx ls
# 4. 现在可以构建多平台镜像了
docker buildx build --platform linux/amd64,linux/arm64 -t your-image:tag . --push



```bash
# docker login

docker buildx build --platform linux/amd64,linux/arm64 -t mark24code/sliceway:latest --push .
```