# 使用 Docker 运行 Sliceway

本项目采用单容器架构，前端静态资源在构建时打包进镜像，由 Ruby 后端提供服务。所有用户数据通过单一数据卷统一管理。

## 前置条件

- Docker

## 快速启动

1. 运行启动脚本：

   ```bash
   chmod +x start_docker.sh
   ./start_docker.sh
   ```

2. 访问应用：
   - 地址：[http://localhost:4567](http://localhost:4567)

## 数据卷说明

Sliceway 使用单一数据卷管理所有持久化数据，默认路径为 `./sliceway-data`，包含以下子目录：

```
sliceway-data/
├── uploads/           # 用户上传的 PSD 文件
├── public/
│   └── processed/     # 处理后的图层图片
├── db/                # SQLite 数据库文件
└── exports/           # 导出的图片文件
```

### 自定义数据目录

通过环境变量 `DATA_VOLUME` 指定自定义数据目录：

```bash
DATA_VOLUME=/your/custom/path ./start_docker.sh
```

示例：

```bash
# 使用绝对路径
DATA_VOLUME=/mnt/storage/sliceway ./start_docker.sh

# 使用相对路径
DATA_VOLUME=./my-sliceway-data ./start_docker.sh
```

## 技术架构

- **基础镜像**：Ruby 3.3 Alpine
- **前端**：React + Vite（构建时打包到 `/app/dist`）
- **后端**：Sinatra + Puma（5 线程）
- **数据库**：SQLite 3
- **图像处理**：ImageMagick + RMagick

### 目录结构说明

```
容器内部：
/app/dist/              # 前端静态资源（只读，构建时打包）
  ├── assets/           # JS、CSS 等
  └── index.html        # SPA 入口

/data/                  # 用户数据（卷挂载，可读写）
  ├── uploads/          # 上传的 PSD 文件
  ├── public/
  │   └── processed/    # 处理后的图片
  ├── db/               # SQLite 数据库
  └── exports/          # 导出的文件
```

## 常用命令

### 查看日志

```bash
docker logs -f sliceway
```

### 停止服务

```bash
docker stop sliceway
```

### 启动服务

```bash
docker start sliceway
```

### 重启服务

```bash
docker restart sliceway
```

### 删除容器

```bash
docker rm -f sliceway
```

### 重新构建并启动

```bash
./start_docker.sh
```

## 数据备份与迁移

### 备份数据

```bash
# 备份整个数据目录
tar -czf sliceway-backup-$(date +%Y%m%d).tar.gz sliceway-data/
```

### 恢复数据

```bash
# 解压到指定位置
tar -xzf sliceway-backup-20241130.tar.gz

# 使用备份数据启动
DATA_VOLUME=/path/to/restored/sliceway-data ./start_docker.sh
```

### 迁移到新服务器

```bash
# 在旧服务器上
docker stop sliceway
tar -czf sliceway-data.tar.gz sliceway-data/

# 传输到新服务器
scp sliceway-data.tar.gz user@newserver:/path/to/

# 在新服务器上
tar -xzf sliceway-data.tar.gz
./start_docker.sh
```

## 端口配置

默认使用 4567 端口，如需修改，可在启动时指定：

```bash
docker run -d \
  --name sliceway \
  -p 8080:4567 \
  -v "$(pwd)/sliceway-data":/data \
  --restart unless-stopped \
  sliceway:latest
```

## 故障排查

### 容器无法启动

```bash
# 查看详细日志
docker logs sliceway

# 检查数据目录权限
ls -la sliceway-data/
```

### 数据库错误

```bash
# 进入容器
docker exec -it sliceway sh

# 检查数据库
cd /data/db
ls -la
```

### 清空所有数据重新开始

```bash
# 停止并删除容器
docker rm -f sliceway

# 删除数据目录
rm -rf sliceway-data/

# 重新启动
./start_docker.sh
```

## 环境变量

容器内置环境变量：

- `RACK_ENV=production`
- `UPLOADS_PATH=/data/uploads` - 上传文件存储路径
- `PUBLIC_PATH=/data/public` - 用户生成的公共文件路径
- `STATIC_PATH=/app/dist` - 前端静态资源路径（构建时打包）
- `DB_PATH=/data/db/production.sqlite3` - 数据库文件路径
- `EXPORTS_PATH=/data/exports` - 导出文件路径


## example

`DATA_VOLUME=/Users/mark24/Downloads/export ./start_docker.sh`
