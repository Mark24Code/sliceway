# Sliceway - Go 版本

现代化的 Photoshop 文件处理和导出工具 - Golang 实现

## 🎉 项目概述

这是 Sliceway 项目的完整 Go 语言实现版本，从 Ruby (Sinatra) 后端完全迁移而来。

### 主要特性

- ✅ **完整 PSD 解析** - 支持图层、组、切片的完整提取
- ✅ **多倍率导出** - 1x, 2x, 4x 等任意缩放比例
- ✅ **智能裁剪** - 自动去除透明边缘和画布外内容
- ✅ **高性能并发** - 基于 Goroutine 的异步处理
- ✅ **WebP 预览** - 自动生成高质量预览图
- ✅ **RESTful API** - 完整的 HTTP API 接口
- ✅ **前端集成** - 前端由 Go 服务器渲染
- ✅ **自动化构建** - Makefile 管理所有任务

## 🚀 快速开始

```bash
# 1. 检查环境
make check

# 2. 完整构建（前端+后端）
make build

# 3. 启动服务
make serve
```

访问 http://localhost:4567 即可使用！

**详细说明**: 查看 [QUICK_START.md](QUICK_START.md)

## 📋 Makefile 命令

类似 Ruby 的 Rakefile，使用 Makefile 管理所有自动化任务：

```bash
# 查看所有命令
make help

# 常用命令
make install       # 安装所有依赖
make build         # 构建完整项目
make serve         # 启动服务（前端+后端）
make dev           # 开发模式
make test          # 运行测试
make clean         # 清理构建产物
make docker-build  # 构建 Docker 镜像
```

**完整指南**: 查看 [MAKEFILE_GUIDE.md](MAKEFILE_GUIDE.md)

## 🚀 性能提升

与 Ruby 版本相比：

| 指标 | Ruby 版本 | Go 版本 | 提升 |
|------|----------|---------|------|
| 启动时间 | 2-3秒 | <100ms | **30倍** ⚡ |
| 内存占用 | 100-200MB | 30-50MB | **60%减少** 💾 |
| 并发模型 | 多进程 | Goroutine | **更轻量** 🚀 |

## 📋 技术栈

**后端**
- **Web 框架**: Gin v1.11.0
- **ORM**: GORM v1.31.1
- **数据库**: SQLite3
- **PSD 解析**: Mark24Code/psd (本地库)
- **图像处理**: disintegration/imaging v1.6.2
- **WebP 支持**: chai2010/webp v1.4.0

**前端**
- **框架**: React 19 + TypeScript
- **构建**: Vite 7
- **UI**: Ant Design 6
- **路由**: React Router 7

## 🏗️ 项目结构

```
psd2img/
├── cmd/server/          # Go 主程序入口
├── internal/            # Go 私有代码
│   ├── config/          # 配置管理
│   ├── database/        # 数据库
│   ├── handler/         # HTTP 处理器
│   ├── middleware/      # 中间件
│   ├── models/          # 数据模型
│   ├── processor/       # PSD 处理器
│   └── service/         # 业务逻辑
├── frontend/            # React 前端源码
├── dist/                # 前端构建产物
├── psd/                 # PSD 库（本地）
├── Makefile             # 自动化脚本
├── Dockerfile           # Docker 配置
└── README_GO.md         # 本文件
```

## 🔧 安装和运行

### 方式1: 使用 Makefile（推荐）

```bash
# 完整构建
make build

# 启动服务（前端由后端渲染）
make serve
```

### 方式2: 手动构建

```bash
# 安装 Go 依赖
export GOPROXY=https://goproxy.cn,direct
go mod download

# 构建前端
cd frontend && npm install && npm run build && cd ..
cp -r frontend/dist ./dist

# 构建后端
go build -o server ./cmd/server

# 运行
STATIC_PATH=dist ./server
```

### 方式3: Docker

```bash
# 使用 Makefile
make docker-build
make docker-run

# 或手动
docker build -t sliceway-go .
docker run -d -p 4567:4567 -v $(pwd)/data:/data sliceway-go
```

## 📡 API 端点

### 系统信息
- `GET /api/version` - 获取版本信息
- `GET /api/system/directories` - 浏览目录

### 项目管理
- `GET /api/projects` - 项目列表
- `POST /api/projects` - 创建项目（上传 PSD）
- `GET /api/projects/:id` - 项目详情
- `DELETE /api/projects/:id` - 删除项目
- `DELETE /api/projects/batch` - 批量删除

### PSD 处理
- `POST /api/projects/:id/process` - 手动触发处理
- `POST /api/projects/:id/stop` - 停止处理

### 图层管理
- `GET /api/projects/:id/layers` - 获取图层列表

### 导出功能
- `POST /api/projects/:id/export` - 导出图层

### 静态文件
- `GET /processed/*` - 访问处理后的文件
- `GET /` - 前端应用（SPA）

## 💻 使用示例

### 上传 PSD 文件

```bash
curl -X POST http://localhost:4567/api/projects \
  -F "file=@design.psd" \
  -F "name=My Project" \
  -F "export_scales[]=1x" \
  -F "export_scales[]=2x" \
  -F "processing_mode=aggressive"
```

### 获取项目列表

```bash
curl http://localhost:4567/api/projects
```

### 导出图层

```bash
curl -X POST http://localhost:4567/api/projects/1/export \
  -H "Content-Type: application/json" \
  -d '{
    "layer_ids": [1, 2, 3],
    "scales": ["1x", "2x"],
    "trim_transparent": true
  }'
```

## ⚙️ 配置

通过环境变量配置：

```bash
# 服务器端口
PORT=4567

# 文件路径
UPLOADS_PATH=uploads
PUBLIC_PATH=public
EXPORTS_PATH=exports
STATIC_PATH=dist          # 前端静态文件

# 数据库
DB_PATH=db/development.sqlite3

# 运行环境
APP_ENV=development  # 或 production
GIN_MODE=debug       # 或 release
```

## 🎯 核心功能

### 1. PSD 处理流程

```
上传 PSD → 解析 → 提取图层树 → 处理图层 → 多倍率缩放 → 保存数据库
```

### 2. 增强模式

`processing_mode=aggressive`:
- ✅ 自动裁剪透明边缘
- ✅ 裁剪到画布边界
- ✅ 跳过完全透明图层

### 3. 多倍率导出

```
layer_name.png       # 1x
layer_name@2x.png    # 2x
layer_name@4x.png    # 4x
```

### 4. 前端集成

Go 服务器自动渲染前端：
- ✅ 从 `dist/` 目录提供静态文件
- ✅ SPA 路由支持
- ✅ API 代理
- ✅ 处理文件访问

## 🛠️ 开发

### 开发模式1: 前端由后端渲染

```bash
make build   # 构建前端+后端
make serve   # 启动服务
```

访问 http://localhost:4567

### 开发模式2: 前后端分离

```bash
# 终端1: 前端开发服务器（热重载）
make dev-frontend

# 终端2: 后端开发服务器
make dev-backend
```

前端: http://localhost:5173  
后端: http://localhost:4567

### 代码格式化

```bash
make fmt    # 格式化代码
make lint   # 代码检查
```

### 测试

```bash
make test         # 运行测试
make test-cover   # 生成覆盖率报告
```

## 📦 依赖管理

```bash
# 安装依赖
make install

# 更新依赖
make deps

# Go 依赖
go get github.com/example/package
go mod tidy

# 前端依赖
cd frontend && npm install
```

## 🐛 调试

```bash
# 详细日志
APP_ENV=development make serve

# 数据库查看
make db-console

# Docker 日志
make docker-logs
```

## 🔒 安全性

- ✅ 文件大小限制
- ✅ 路径遍历保护
- ✅ CORS 配置
- ✅ 非 root 用户（Docker）
- ✅ 健康检查

## 📝 从 Ruby 迁移

### 兼容性

- ✅ 数据库结构相同
- ✅ API 接口相同
- ✅ 文件路径相同
- ✅ 前端无需修改

### 数据迁移

```bash
# 复制数据库
cp ruby/db/production.sqlite3 db/production.sqlite3

# 自动迁移
./server
```

### Rakefile → Makefile

| Rakefile | Makefile |
|----------|----------|
| `rake install` | `make install` |
| `rake build` | `make build` |
| `rake run` | `make run` |
| `rake test` | `make test` |
| `rake clean` | `make clean` |

## 📚 文档

- [QUICK_START.md](QUICK_START.md) - 快速开始指南
- [MAKEFILE_GUIDE.md](MAKEFILE_GUIDE.md) - Makefile 使用指南
- [GO_IMPLEMENTATION_SUMMARY.md](GO_IMPLEMENTATION_SUMMARY.md) - 实现总结
- [MIGRATION_COMPLETE.md](MIGRATION_COMPLETE.md) - 迁移完成报告

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 🙏 致谢

- [Mark24Code/psd](https://github.com/Mark24Code/psd) - PSD 解析
- [Gin](https://github.com/gin-gonic/gin) - Web 框架
- [GORM](https://gorm.io/) - ORM

---

**100% 完整的 Go 实现！前端由 Go 服务器渲染！** 🎉
