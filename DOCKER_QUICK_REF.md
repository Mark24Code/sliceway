# Sliceway Docker 快速参考

## 🚀 快速启动

```bash
./start_docker.sh
```

访问：http://localhost:4567

---

## 📝 常用命令

| 操作     | 命令                          |
| -------- | ----------------------------- |
| 启动     | `./start_docker.sh`           |
| 停止     | `docker stop sliceway`        |
| 重启     | `docker restart sliceway`     |
| 日志     | `docker logs -f sliceway`     |
| 进入容器 | `docker exec -it sliceway sh` |
| 删除容器 | `docker rm -f sliceway`       |

---

## 📂 数据位置

| 数据类型   | 位置                              |
| ---------- | --------------------------------- |
| 上传的 PSD | `sliceway-data/uploads/`          |
| 处理后图片 | `sliceway-data/public/processed/` |
| 数据库     | `sliceway-data/db/`               |
| 导出文件   | `sliceway-data/exports/`          |

---

## 🔧 自定义配置

### 自定义数据目录

```bash
DATA_VOLUME=/your/path ./start_docker.sh
```

### 自定义端口

```bash
docker run -d \
  --name sliceway \
  -p 8080:4567 \
  -v "$(pwd)/sliceway-data":/data \
  sliceway:latest
```

---

## 💾 备份与恢复

### 备份

```bash
tar -czf backup.tar.gz sliceway-data/
```

### 恢复

```bash
tar -xzf backup.tar.gz
./start_docker.sh
```

---

## 🐛 故障排查

### 查看日志

```bash
docker logs sliceway
```

### 检查数据目录

```bash
ls -la sliceway-data/
```

### 重建容器

```bash
docker stop sliceway
docker rm sliceway
./start_docker.sh
```

### 完全清理

```bash
docker rm -f sliceway
docker rmi sliceway:latest
rm -rf sliceway-data/
./start_docker.sh
```

---

## 📚 完整文档

- `DOCKER_README.md` - 详细使用指南
- `DOCKER_TEST_GUIDE.md` - 测试流程
- `DOCKER_MIGRATION.md` - 迁移说明

---

## 💡 提示

- 数据保存在 `sliceway-data/` 目录
- 删除容器不会删除数据
- 建议定期备份数据目录
- 首次启动会自动初始化数据库
