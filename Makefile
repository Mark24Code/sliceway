# Sliceway - Go 版本自动化构建脚本
# 类似 Ruby 的 Rakefile

.PHONY: all build run dev test clean install frontend backend docker help

# 默认任务
all: install build

# 颜色定义
BLUE := \033[34m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
RESET := \033[0m

# 项目配置
APP_NAME := server
BUILD_DIR := build
DIST_DIR := dist
FRONTEND_DIR := frontend
GO_FILES := $(shell find . -type f -name '*.go' -not -path "./vendor/*")

# Go 配置
GOPROXY := https://goproxy.cn,direct
GOFLAGS := CGO_ENABLED=1
LDFLAGS := -ldflags="-s -w"

# 版本信息
VERSION := $(shell cat VERSION 2>/dev/null || echo "dev")
BUILD_TIME := $(shell date +%Y-%m-%d_%H:%M:%S)
GIT_COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")

##@ 帮助

help: ## 显示帮助信息
	@echo "$(BLUE)Sliceway - Go 版本自动化构建工具$(RESET)"
	@echo ""
	@echo "$(GREEN)使用方法:$(RESET)"
	@echo "  make <target>"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "\n$(YELLOW)可用命令:$(RESET)\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(BLUE)%-15s$(RESET) %s\n", $$1, $$2 } /^##@/ { printf "\n$(GREEN)%s$(RESET)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ 开发环境

install: ## 安装所有依赖（前端+后端）
	@echo "$(BLUE)>>> 安装依赖...$(RESET)"
	@echo "$(YELLOW)>>> 安装 Go 依赖...$(RESET)"
	@export GOPROXY=$(GOPROXY) && go mod download
	@echo "$(YELLOW)>>> 安装前端依赖...$(RESET)"
	@cd $(FRONTEND_DIR) && npm install
	@echo "$(GREEN)✓ 依赖安装完成$(RESET)"

install-go: ## 仅安装 Go 依赖
	@echo "$(BLUE)>>> 安装 Go 依赖...$(RESET)"
	@export GOPROXY=$(GOPROXY) && go mod download
	@echo "$(GREEN)✓ Go 依赖安装完成$(RESET)"

install-frontend: ## 仅安装前端依赖
	@echo "$(BLUE)>>> 安装前端依赖...$(RESET)"
	@cd $(FRONTEND_DIR) && npm install
	@echo "$(GREEN)✓ 前端依赖安装完成$(RESET)"

##@ 构建任务

frontend: ## 构建前端静态文件
	@echo "$(BLUE)>>> 构建前端...$(RESET)"
	@cd $(FRONTEND_DIR) && npm run build
	@echo "$(YELLOW)>>> 复制前端产物到 dist/...$(RESET)"
	@rm -rf $(DIST_DIR)
	@mkdir -p $(DIST_DIR)
	@cp -r $(FRONTEND_DIR)/dist/* $(DIST_DIR)/
	@echo "$(GREEN)✓ 前端构建完成: $(DIST_DIR)/$(RESET)"

backend: ## 构建 Go 后端
	@echo "$(BLUE)>>> 构建后端...$(RESET)"
	@$(GOFLAGS) go build $(LDFLAGS) -o $(APP_NAME) ./cmd/server
	@echo "$(GREEN)✓ 后端构建完成: ./$(APP_NAME)$(RESET)"

build: frontend backend ## 构建完整项目（前端+后端）
	@echo "$(GREEN)✓ 完整构建完成！$(RESET)"
	@echo "$(YELLOW)  前端产物: $(DIST_DIR)/$(RESET)"
	@echo "$(YELLOW)  后端二进制: ./$(APP_NAME)$(RESET)"
	@echo "$(YELLOW)  版本: $(VERSION)$(RESET)"

build-prod: ## 生产环境构建（优化）- 需要 Docker
	@echo "$(BLUE)>>> 生产环境构建（使用 Docker）...$(RESET)"
	@echo "$(YELLOW)>>> 注意: 由于 PSD 库依赖 CGO，Linux 版本需要 Docker 构建$(RESET)"
	@which docker > /dev/null || (echo "$(RED)错误: 需要安装 Docker$(RESET)" && exit 1)
	@echo "$(YELLOW)>>> 1. 构建前端...$(RESET)"
	@cd $(FRONTEND_DIR) && npm run build
	@rm -rf $(DIST_DIR)
	@mkdir -p $(DIST_DIR) $(BUILD_DIR)
	@cp -r $(FRONTEND_DIR)/dist/* $(DIST_DIR)/
	@echo "$(YELLOW)>>> 2. 使用 Docker 构建 Linux AMD64 版本...$(RESET)"
	@bash scripts/build-linux.sh
	@echo "$(YELLOW)>>> 3. 构建 macOS AMD64 版本...$(RESET)"
	@CGO_ENABLED=1 GOOS=darwin GOARCH=amd64 go build $(LDFLAGS) \
		-o $(BUILD_DIR)/$(APP_NAME)-darwin-amd64 ./cmd/server
	@echo "$(YELLOW)>>> 4. 构建 macOS ARM64 版本...$(RESET)"
	@CGO_ENABLED=1 GOOS=darwin GOARCH=arm64 go build $(LDFLAGS) \
		-o $(BUILD_DIR)/$(APP_NAME)-darwin-arm64 ./cmd/server
	@echo "$(GREEN)✓ 生产构建完成: $(BUILD_DIR)/$(RESET)"
	@ls -lh $(BUILD_DIR)/

build-prod-local: ## 生产环境构建（仅本地平台）
	@echo "$(BLUE)>>> 本地平台构建...$(RESET)"
	@cd $(FRONTEND_DIR) && npm run build
	@rm -rf $(DIST_DIR)
	@mkdir -p $(DIST_DIR) $(BUILD_DIR)
	@cp -r $(FRONTEND_DIR)/dist/* $(DIST_DIR)/
	@echo "$(YELLOW)>>> 构建当前平台版本...$(RESET)"
	@CGO_ENABLED=1 go build $(LDFLAGS) \
		-o $(BUILD_DIR)/$(APP_NAME)-$(shell go env GOOS)-$(shell go env GOARCH) ./cmd/server
	@echo "$(GREEN)✓ 本地构建完成: $(BUILD_DIR)/$(RESET)"
	@ls -lh $(BUILD_DIR)/

##@ 运行服务

run: build ## 构建并运行服务器
	@echo "$(BLUE)>>> 启动服务器...$(RESET)"
	@./$(APP_NAME)

dev: ## 开发模式（前端+后端并行）
	@echo "$(BLUE)>>> 启动开发环境...$(RESET)"
	@echo "$(YELLOW)  前端: http://localhost:5173$(RESET)"
	@echo "$(YELLOW)  后端: http://localhost:4567$(RESET)"
	@$(MAKE) -j2 dev-frontend dev-backend

dev-frontend: ## 仅启动前端开发服务器
	@echo "$(BLUE)>>> 启动前端开发服务器...$(RESET)"
	@cd $(FRONTEND_DIR) && npm run dev

dev-backend: backend ## 仅启动后端开发服务器
	@echo "$(BLUE)>>> 启动后端开发服务器...$(RESET)"
	@./$(APP_NAME)

serve: build ## 启动完整服务（前端由后端渲染）
	@echo "$(BLUE)>>> 启动完整服务...$(RESET)"
	@echo "$(YELLOW)  访问: http://localhost:4567$(RESET)"
	@export STATIC_PATH=$(DIST_DIR) && ./$(APP_NAME)

##@ 测试

test: ## 运行所有测试
	@echo "$(BLUE)>>> 运行测试...$(RESET)"
	@go test -v ./...

test-cover: ## 运行测试并生成覆盖率报告
	@echo "$(BLUE)>>> 运行测试（覆盖率）...$(RESET)"
	@go test -v -coverprofile=coverage.out ./...
	@go tool cover -html=coverage.out -o coverage.html
	@echo "$(GREEN)✓ 覆盖率报告: coverage.html$(RESET)"

test-frontend: ## 运行前端测试
	@echo "$(BLUE)>>> 运行前端测试...$(RESET)"
	@cd $(FRONTEND_DIR) && npm run test 2>/dev/null || echo "$(YELLOW)前端暂无测试$(RESET)"

lint: ## 代码检查
	@echo "$(BLUE)>>> 运行代码检查...$(RESET)"
	@golangci-lint run ./... 2>/dev/null || go vet ./...
	@cd $(FRONTEND_DIR) && npm run lint

fmt: ## 格式化代码
	@echo "$(BLUE)>>> 格式化代码...$(RESET)"
	@go fmt ./...
	@gofmt -s -w $(GO_FILES)
	@echo "$(GREEN)✓ 代码格式化完成$(RESET)"

##@ Docker

docker-build: ## 构建 Docker 镜像
	@echo "$(BLUE)>>> 构建 Docker 镜像...$(RESET)"
	@docker build -t sliceway-go:$(VERSION) .
	@docker tag sliceway-go:$(VERSION) sliceway-go:latest
	@echo "$(GREEN)✓ Docker 镜像构建完成$(RESET)"
	@echo "$(YELLOW)  镜像: sliceway-go:$(VERSION)$(RESET)"
	@echo "$(YELLOW)  镜像: sliceway-go:latest$(RESET)"

docker-run: docker-build ## 运行 Docker 容器
	@echo "$(BLUE)>>> 启动 Docker 容器...$(RESET)"
	@docker run -d \
		-p 4567:4567 \
		-v $(PWD)/data:/data \
		--name sliceway \
		sliceway-go:latest
	@echo "$(GREEN)✓ 容器启动成功$(RESET)"
	@echo "$(YELLOW)  访问: http://localhost:4567$(RESET)"
	@echo "$(YELLOW)  日志: docker logs -f sliceway$(RESET)"

docker-stop: ## 停止 Docker 容器
	@echo "$(BLUE)>>> 停止 Docker 容器...$(RESET)"
	@docker stop sliceway 2>/dev/null || true
	@docker rm sliceway 2>/dev/null || true
	@echo "$(GREEN)✓ 容器已停止$(RESET)"

docker-logs: ## 查看 Docker 容器日志
	@docker logs -f sliceway

##@ 清理

clean: ## 清理构建产物
	@echo "$(BLUE)>>> 清理构建产物...$(RESET)"
	@rm -f $(APP_NAME)
	@rm -rf $(BUILD_DIR)
	@rm -rf $(DIST_DIR)
	@rm -f coverage.out coverage.html
	@echo "$(GREEN)✓ 清理完成$(RESET)"

clean-all: clean ## 清理所有文件（包括依赖）
	@echo "$(BLUE)>>> 清理所有文件...$(RESET)"
	@rm -rf vendor/
	@cd $(FRONTEND_DIR) && rm -rf node_modules/
	@echo "$(GREEN)✓ 深度清理完成$(RESET)"

clean-data: ## 清理数据文件
	@echo "$(RED)>>> 清理数据文件...$(RESET)"
	@read -p "确认删除所有数据？[y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		rm -rf uploads/* public/processed/* db/*.sqlite3 exports/*; \
		echo "$(GREEN)✓ 数据清理完成$(RESET)"; \
	else \
		echo "$(YELLOW)已取消$(RESET)"; \
	fi

##@ 数据库

db-migrate: backend ## 运行数据库迁移
	@echo "$(BLUE)>>> 数据库迁移...$(RESET)"
	@./$(APP_NAME) &
	@sleep 2
	@pkill -f "./$(APP_NAME)"
	@echo "$(GREEN)✓ 迁移完成$(RESET)"

db-reset: ## 重置数据库
	@echo "$(RED)>>> 重置数据库...$(RESET)"
	@rm -f db/*.sqlite3
	@$(MAKE) db-migrate
	@echo "$(GREEN)✓ 数据库已重置$(RESET)"

db-console: ## 打开数据库控制台
	@sqlite3 db/development.sqlite3

##@ 工具

watch: ## 监听文件变化自动重新构建
	@echo "$(BLUE)>>> 监听文件变化...$(RESET)"
	@which fswatch > /dev/null || (echo "$(RED)请安装 fswatch: brew install fswatch$(RESET)" && exit 1)
	@fswatch -o $(GO_FILES) | xargs -n1 -I{} make backend

version: ## 显示版本信息
	@echo "$(BLUE)Sliceway$(RESET)"
	@echo "  版本: $(VERSION)"
	@echo "  构建时间: $(BUILD_TIME)"
	@echo "  Git Commit: $(GIT_COMMIT)"

info: ## 显示项目信息
	@echo "$(BLUE)项目信息:$(RESET)"
	@echo "  名称: Sliceway"
	@echo "  版本: $(VERSION)"
	@echo "  Go 版本: $(shell go version)"
	@echo "  Node 版本: $(shell node --version 2>/dev/null || echo 'N/A')"
	@echo "  构建目录: $(BUILD_DIR)"
	@echo "  前端目录: $(FRONTEND_DIR)"
	@echo "  静态产物: $(DIST_DIR)"

deps: ## 更新所有依赖
	@echo "$(BLUE)>>> 更新依赖...$(RESET)"
	@export GOPROXY=$(GOPROXY) && go get -u ./...
	@go mod tidy
	@cd $(FRONTEND_DIR) && npm update
	@echo "$(GREEN)✓ 依赖更新完成$(RESET)"

check: ## 检查环境
	@echo "$(BLUE)>>> 检查开发环境...$(RESET)"
	@echo -n "Go: "
	@go version 2>/dev/null || echo "$(RED)未安装$(RESET)"
	@echo -n "Node: "
	@node --version 2>/dev/null || echo "$(RED)未安装$(RESET)"
	@echo -n "npm: "
	@npm --version 2>/dev/null || echo "$(RED)未安装$(RESET)"
	@echo -n "Docker: "
	@docker --version 2>/dev/null || echo "$(YELLOW)未安装（可选）$(RESET)"
	@echo -n "SQLite: "
	@sqlite3 --version 2>/dev/null || echo "$(RED)未安装$(RESET)"
	@echo "$(GREEN)✓ 环境检查完成$(RESET)"

##@ 快速开始

quickstart: install build serve ## 快速开始（安装+构建+运行）

setup: check install build ## 初始化项目环境

deploy-local: build-prod docker-build ## 本地部署准备

# 默认目标
.DEFAULT_GOAL := help
