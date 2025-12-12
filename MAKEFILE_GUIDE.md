# Makefile 使用指南

类似 Ruby 的 Rakefile，我们使用 Makefile 来管理所有自动化任务。

## 🚀 快速开始

### 首次使用
```bash
# 1. 检查环境
make check

# 2. 初始化项目（安装依赖+构建）
make setup

# 3. 启动服务器（前端由后端渲染）
make serve
```

访问 http://localhost:4567 即可看到完整应用！

### 日常开发
```bash
# 完整构建（前端+后端）
make build

# 运行服务器
make run

# 或使用快捷命令
make serve
```

## 📋 常用命令

### 开发环境

```bash
# 安装所有依赖
make install

# 仅安装 Go 依赖
make install-go

# 仅安装前端依赖
make install-frontend

# 更新所有依赖到最新版本
make deps
```

### 构建

```bash
# 构建前端静态文件
make frontend
# 产物位置: dist/

# 构建后端
make backend
# 产物位置: ./server

# 完整构建（前端+后端）
make build

# 生产环境构建（多平台）
make build-prod
# 产物位置: build/server-*
```

### 运行

```bash
# 构建并运行
make run

# 开发模式（前端5173 + 后端4567）
make dev

# 仅前端开发服务器
make dev-frontend

# 仅后端开发服务器
make dev-backend

# 完整服务（前端由后端渲染）
make serve
```

### 测试

```bash
# 运行所有测试
make test

# 运行测试并生成覆盖率报告
make test-cover

# 前端测试
make test-frontend

# 代码检查
make lint

# 格式化代码
make fmt
```

### Docker

```bash
# 构建 Docker 镜像
make docker-build

# 运行 Docker 容器
make docker-run

# 停止容器
make docker-stop

# 查看日志
make docker-logs
```

### 清理

```bash
# 清理构建产物
make clean

# 深度清理（包括依赖）
make clean-all

# 清理数据文件（谨慎！）
make clean-data
```

### 数据库

```bash
# 数据库迁移
make db-migrate

# 重置数据库
make db-reset

# 打开数据库控制台
make db-console
```

### 工具

```bash
# 显示版本信息
make version

# 显示项目信息
make info

# 检查开发环境
make check

# 监听文件变化自动构建
make watch
```

## 🎯 典型工作流

### 场景1: 首次克隆项目

```bash
git clone <repository>
cd psd2img

# 检查环境
make check

# 初始化（安装依赖+构建）
make setup

# 启动服务
make serve

# 访问 http://localhost:4567
```

### 场景2: 日常开发

```bash
# 修改代码后...

# 重新构建
make build

# 运行服务器
make serve
```

### 场景3: 前端开发

```bash
# 终端1: 启动前端开发服务器（热重载）
make dev-frontend

# 终端2: 启动后端服务器
make dev-backend

# 前端: http://localhost:5173
# 后端: http://localhost:4567
```

### 场景4: 生产部署

```bash
# 完整构建
make build

# Docker 部署
make docker-build
make docker-run

# 或者直接运行二进制
STATIC_PATH=dist ./server
```

### 场景5: 测试

```bash
# 格式化代码
make fmt

# 运行测试
make test

# 查看覆盖率
make test-cover
open coverage.html
```

## 📊 Makefile vs Rakefile

从 Ruby Rakefile 迁移到 Makefile 的对应关系：

| Rakefile | Makefile | 说明 |
|----------|----------|------|
| `rake install` | `make install` | 安装依赖 |
| `rake build` | `make build` | 构建项目 |
| `rake run` | `make run` | 运行服务器 |
| `rake test` | `make test` | 运行测试 |
| `rake clean` | `make clean` | 清理产物 |
| `rake db:migrate` | `make db-migrate` | 数据库迁移 |
| `rake docker:build` | `make docker-build` | Docker 构建 |

## 🎨 自定义任务

你可以在 Makefile 中添加自己的任务：

```makefile
##@ 我的任务

my-task: ## 我的自定义任务
	@echo "执行自定义任务..."
	# 你的命令
```

## 💡 提示

### 1. 查看帮助
```bash
make help
# 或
make
```

### 2. 并行构建
某些任务可以并行执行：
```bash
make -j4 build  # 使用4个并行任务
```

### 3. 环境变量
```bash
PORT=8080 make serve
STATIC_PATH=custom/path make serve
```

### 4. 调试 Makefile
```bash
make -n build  # 只显示命令，不执行
```

### 5. 前端由后端渲染
运行 `make serve` 后，Go 服务器会：
- 在 http://localhost:4567 提供完整应用
- 自动渲染 dist/ 中的前端静态文件
- 处理 SPA 路由（所有非 API 路由返回 index.html）
- 提供 API 服务（/api/*）
- 提供处理后的文件（/processed/*）

## 🔧 常见问题

### Q: make command not found
A: 需要安装 make
```bash
# macOS
xcode-select --install

# Linux
sudo apt-get install build-essential
```

### Q: 前端构建失败
A: 确保安装了 Node.js 和 npm
```bash
make check
make install-frontend
```

### Q: Go 构建失败
A: 确保安装了 Go 1.21+
```bash
go version
make install-go
```

### Q: 端口被占用
A: 停止现有服务器
```bash
pkill -f "./server"
# 或修改端口
PORT=8080 make serve
```

### Q: 前端显示空白
A: 确保前端已构建
```bash
make frontend
ls -la dist/
```

## 📚 更多信息

- 查看 `README_GO.md` 了解项目详情
- 查看 `GO_IMPLEMENTATION_SUMMARY.md` 了解实现细节
- 运行 `make help` 查看所有可用命令

---

**Makefile 让构建和部署变得简单！** 🚀
