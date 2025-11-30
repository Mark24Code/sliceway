# 使用 Docker 运行 Sliceway

本项目以单容器应用方式运行，前端由 Ruby 后端构建并提供服务。

## 前置条件

- Docker
- Docker Compose

## 快速启动

1. 运行启动脚本：

   ```bash
   ./start_docker.sh
   ```

2. 访问应用：
   - 地址：[http://localhost:4567](http://localhost:4567)

## 自定义挂载卷路径

你可以通过设置以下环境变量，覆盖默认的数据挂载路径：

- `UPLOADS_VOLUME`：上传目录（默认 `./data/uploads`）
- `PUBLIC_VOLUME`：公开资源目录（默认 `./data/public`）
- `DB_VOLUME`：数据库目录（默认 `./data/db`）
- `EXPORTS_VOLUME`：导出目录（默认 `./data/exports`）

示例：

```bash
UPLOADS_VOLUME=/your/path/uploads PUBLIC_VOLUME=/your/path/public DB_VOLUME=/your/path/db EXPORTS_VOLUME=/your/path/exports ./start_docker.sh
```

## 环境说明

- **容器**：Ruby 3.3 (Alpine) + 已构建前端资源
- **服务端**：Puma（5 线程），生产模式

## 停止服务

停止应用：

```bash
docker-compose down
```
