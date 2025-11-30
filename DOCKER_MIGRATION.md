# Docker 重构更新说明

## 概述

本次重构将 Sliceway 从 Docker Compose 多容器架构改为单一 Docker 容器架构，简化了部署流程，统一了数据管理。

## 主要变化

### 1. 架构简化

**之前**：

- 使用 Docker Compose 管理多个卷
- 需要分别挂载 uploads、public、db、exports 四个目录
- 配置相对复杂

**现在**：

- 单一 Docker 容器
- 统一数据卷 `/data`，包含所有子目录
- 一个命令即可启动

### 2. 前端构建方式

**之前**：

- 前端构建产物放在 `dist` 目录
- 使用 `STATIC_PATH` 环境变量

**现在**：

- 前端构建产物在 Docker build 阶段打包到 `public/dist`
- 由 Ruby 后端直接提供前端静态文件服务
- 简化了路径管理

### 3. 数据卷结构

统一的数据卷结构：

```
/data/                    # 容器内挂载点
├── uploads/              # 用户上传的 PSD 文件
├── public/
│   └── processed/        # 处理后的图层图片
├── db/                   # SQLite 数据库
└── exports/              # 导出的图片文件
```

宿主机默认路径：`./sliceway-data/`

### 4. 启动方式

**之前**：

```bash
# 使用 docker-compose
docker-compose up --build -d
```

**现在**：

```bash
# 使用简单的启动脚本
./start_docker.sh

# 或自定义数据目录
DATA_VOLUME=/custom/path ./start_docker.sh
```

## 文件修改清单

### 1. Dockerfile

- 将前端构建产物复制到 `public/dist` 而非独立的 `dist` 目录
- 创建 `/data` 目录及其子目录结构
- 更新环境变量以使用 `/data` 路径
- 添加数据库迁移到启动命令

### 2. start_docker.sh

- 简化为纯 Docker 命令（不再使用 docker-compose）
- 支持通过 `DATA_VOLUME` 环境变量自定义数据目录
- 自动创建数据目录结构
- 提供更清晰的使用说明

### 3. app.rb

- 添加 `public_path` 辅助方法
- 更新所有硬编码的 `'public'` 路径为使用 `ENV['PUBLIC_PATH']`
- 修改前端资源服务路径为 `public/dist`
- 确保所有文件操作使用环境变量路径

### 4. lib/psd_processor.rb

- 更新 `@output_dir` 使用 `ENV['PUBLIC_PATH']`
- 确保图片处理路径正确

### 5. DOCKER_README.md

- 完全重写，反映新的单容器架构
- 添加详细的使用说明
- 包含故障排查指南
- 添加数据备份和迁移说明

### 6. 新增文件

- `.dockerignore`: 优化 Docker 构建，排除不必要的文件
- `DOCKER_TEST_GUIDE.md`: 完整的测试指南

### 7. 删除/废弃文件

- `docker-compose.yml`: 不再需要（可以删除或保留作为参考）

## 环境变量对照表

### 容器内环境变量

| 变量名         | 值                            | 说明           |
| -------------- | ----------------------------- | -------------- |
| `RACK_ENV`     | `production`                  | Ruby 运行环境  |
| `UPLOADS_PATH` | `/data/uploads`               | 上传文件目录   |
| `PUBLIC_PATH`  | `/data/public`                | 公共资源目录   |
| `DB_PATH`      | `/data/db/production.sqlite3` | 数据库文件路径 |
| `EXPORTS_PATH` | `/data/exports`               | 导出目录       |

### 宿主机环境变量

| 变量名        | 默认值            | 说明           |
| ------------- | ----------------- | -------------- |
| `DATA_VOLUME` | `./sliceway-data` | 数据卷挂载路径 |

## 迁移指南

### 从旧版本迁移

如果你已经在使用旧版本的 Docker 配置：

1. **备份现有数据**：

   ```bash
   # 假设你使用了默认的 data 目录
   cp -r data/ sliceway-data/
   ```

2. **调整目录结构**：

   ```bash
   cd sliceway-data
   # 确保 processed 目录在 public 下
   mkdir -p public
   mv processed public/ 2>/dev/null || true
   ```

3. **停止旧容器**：

   ```bash
   docker-compose down
   ```

4. **启动新容器**：
   ```bash
   ./start_docker.sh
   ```

### 全新部署

直接运行：

```bash
./start_docker.sh
```

## 优势

1. **更简单的部署**：一个命令即可启动
2. **统一的数据管理**：所有数据在一个卷中，便于备份和迁移
3. **更好的性能**：减少了容器间通信开销
4. **更容易维护**：配置文件更少，逻辑更清晰
5. **更灵活的数据管理**：可以轻松自定义数据目录位置

## 常用命令

```bash
# 启动
./start_docker.sh

# 查看日志
docker logs -f sliceway

# 停止
docker stop sliceway

# 重启
docker restart sliceway

# 删除容器（保留数据）
docker rm -f sliceway

# 进入容器调试
docker exec -it sliceway sh

# 备份数据
tar -czf backup-$(date +%Y%m%d).tar.gz sliceway-data/

# 使用自定义数据目录
DATA_VOLUME=/mnt/storage/sliceway ./start_docker.sh
```

## 注意事项

1. 首次启动时会自动进行数据库迁移
2. 数据卷默认在当前目录的 `sliceway-data/` 下
3. 删除容器不会删除数据，数据保存在宿主机
4. 如需完全清理，需手动删除数据目录
5. 建议定期备份 `sliceway-data/` 目录

## 问题反馈

如遇到问题，请检查：

1. Docker 日志：`docker logs sliceway`
2. 数据目录权限：`ls -la sliceway-data/`
3. 容器内部状态：`docker exec -it sliceway sh`
