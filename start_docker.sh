
#!/bin/bash

# 切换到脚本所在目录，保证无论从哪里调用都能正确执行
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# 设置默认数据卷路径
DATA_VOLUME="${DATA_VOLUME:-./sliceway-data}"

# 创建数据卷目录结构
echo "初始化数据目录: $DATA_VOLUME"
mkdir -p "$DATA_VOLUME/uploads"
mkdir -p "$DATA_VOLUME/public/processed"
mkdir -p "$DATA_VOLUME/db"
mkdir -p "$DATA_VOLUME/exports"

# 构建镜像
echo "构建 Sliceway Docker 镜像..."
docker build -t sliceway:latest .

# 停止并删除旧容器（如果存在）
docker stop sliceway 2>/dev/null && docker rm sliceway 2>/dev/null

# 启动新容器
echo "启动 Sliceway 容器..."
docker run -d \
  --name sliceway \
  -p 4567:4567 \
  -v "$(cd "$DATA_VOLUME" && pwd)":/data \
  --restart unless-stopped \
  sliceway:latest

echo "-----------------------------------"
echo "✅ Sliceway 已启动"
echo "📂 数据目录: $DATA_VOLUME"
echo "🌐 访问地址: http://localhost:4567"
echo "-----------------------------------"
echo ""
echo "使用说明："
echo "  查看日志: docker logs -f sliceway"
echo "  停止服务: docker stop sliceway"
echo "  启动服务: docker start sliceway"
echo "  删除容器: docker rm -f sliceway"
echo ""
echo "自定义数据目录："
echo "  DATA_VOLUME=/your/custom/path ./start_docker.sh"
