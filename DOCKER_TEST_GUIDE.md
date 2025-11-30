# Docker 部署测试指南

## 测试步骤

### 1. 构建和启动

```bash
cd /Users/tanling/Downloads/sliceway
./start_docker.sh
```

预期结果：

- 创建 `sliceway-data` 目录及其子目录
- 成功构建 Docker 镜像
- 容器成功启动
- 提示访问 http://localhost:4567

### 2. 验证容器运行

```bash
# 查看容器状态
docker ps | grep sliceway

# 查看日志
docker logs sliceway
```

预期结果：

- 容器状态为 Up
- 日志中显示 Puma 成功启动

### 3. 验证数据卷挂载

```bash
# 进入容器
docker exec -it sliceway sh

# 检查挂载点
ls -la /data
ls -la /data/uploads
ls -la /data/public/processed
ls -la /data/db
ls -la /data/exports

# 退出容器
exit
```

预期结果：

- /data 目录存在
- 所有子目录正确创建

### 4. 访问应用

在浏览器中打开：http://localhost:4567

预期结果：

- 前端页面正常加载
- 能看到 React 应用界面

### 5. 测试上传功能

1. 上传一个 PSD 文件
2. 等待处理完成

验证：

```bash
# 检查上传文件
ls -la sliceway-data/uploads/

# 检查处理后的图片
ls -la sliceway-data/public/processed/

# 检查数据库
ls -la sliceway-data/db/
```

### 6. 测试导出功能

1. 导出处理好的图层
2. 验证导出文件

```bash
ls -la sliceway-data/exports/
```

### 7. 测试自定义数据目录

```bash
# 停止现有容器
docker stop sliceway
docker rm sliceway

# 使用自定义目录
DATA_VOLUME=/tmp/my-sliceway-data ./start_docker.sh

# 验证
ls -la /tmp/my-sliceway-data/
```

### 8. 测试容器重启

```bash
# 重启容器
docker restart sliceway

# 验证数据持久化
docker logs sliceway
```

访问应用，确认之前上传的项目仍然存在。

## 常见问题排查

### 问题 1: 容器无法启动

```bash
docker logs sliceway
```

查看具体错误信息。

### 问题 2: 前端页面 404

检查容器内的文件：

```bash
docker exec -it sliceway ls -la /app/public/dist/
```

确认前端构建产物已正确复制。

### 问题 3: 上传文件失败

检查卷权限：

```bash
ls -la sliceway-data/uploads/
docker exec -it sliceway ls -la /data/uploads/
```

### 问题 4: 数据库错误

```bash
docker exec -it sliceway sh
cd /data/db
ls -la
```

如果数据库损坏，删除并重启容器会自动重建。

## 清理

```bash
# 停止并删除容器
docker stop sliceway
docker rm sliceway

# 删除镜像
docker rmi sliceway:latest

# 删除数据（谨慎操作！）
rm -rf sliceway-data/
```

## 环境变量参考

容器内部环境变量：

- `RACK_ENV=production`
- `UPLOADS_PATH=/data/uploads`
- `PUBLIC_PATH=/data/public`
- `DB_PATH=/data/db/production.sqlite3`
- `EXPORTS_PATH=/data/exports`

宿主机环境变量：

- `DATA_VOLUME`: 指定数据卷路径（默认 `./sliceway-data`）
