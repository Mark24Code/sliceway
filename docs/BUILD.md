# 构建说明

## 问题背景

由于 PSD 处理库依赖 CGO（使用了 `github.com/chai2010/webp` 和 `github.com/mattn/go-sqlite3`），在 macOS 上无法直接交叉编译 Linux 版本。

## 解决方案

### 方案 1: 本地平台构建（推荐用于开发）

仅构建当前平台的二进制文件，无需 Docker：

```bash
make build-prod-local
```

**输出**:
- `build/server-darwin-arm64` (M系列 Mac)
- `build/server-darwin-amd64` (Intel Mac)

**优点**:
- ✅ 无需 Docker
- ✅ 构建速度快
- ✅ 适合本地开发和测试

**缺点**:
- ❌ 无法生成 Linux 版本

---

### 方案 2: Docker 多平台构建（推荐用于生产）

使用 Docker 构建所有平台的二进制文件：

```bash
make build-prod
```

**输出**:
- `build/server-linux-amd64` (通过 Docker 构建)
- `build/server-darwin-amd64` (本地构建)
- `build/server-darwin-arm64` (本地构建)

**前提条件**:
- ✅ 需要安装 Docker Desktop
- ✅ Docker 服务正在运行

**优点**:
- ✅ 生成所有平台的二进制文件
- ✅ Linux 版本在容器中正确编译（包含 CGO 支持）
- ✅ 适合部署到 Linux 服务器

**缺点**:
- ❌ 需要 Docker
- ❌ 首次构建较慢（需要下载镜像和依赖）

---

## 为什么不能用 `CGO_ENABLED=0`？

尝试禁用 CGO 会导致编译错误：

```
# github.com/chai2010/webp
webp.go:22:9: undefined: webpGetInfo
...

# github.com/mattn/go-sqlite3
undefined: ...
```

这是因为：
1. `github.com/chai2010/webp` - PSD 库用于 WebP 图像处理，需要 C 绑定
2. `github.com/mattn/go-sqlite3` - 数据库驱动，需要 C 绑定

**替代方案**（未实施）:
- 使用纯 Go 的 `modernc.org/sqlite` 替换 `mattn/go-sqlite3`
- 移除 WebP 支持或使用纯 Go 实现

但这需要修改 PSD 库的依赖，工作量较大。

---

## 快速参考

| 命令 | 用途 | 需要 Docker | 输出平台 |
|------|------|------------|----------|
| `make build` | 开发构建 | ❌ | 当前平台 |
| `make build-prod-local` | 本地生产构建 | ❌ | 当前平台 |
| `make build-prod` | 完整生产构建 | ✅ | Linux + macOS |
| `make docker-build` | Docker 镜像 | ✅ | Linux (镜像) |

---

## Docker 构建详情

### Dockerfile.build 结构

```
阶段1: frontend-builder
  ├── 使用 node:20-alpine
  └── 构建前端静态文件

阶段2: backend-builder
  ├── 使用 golang:1.23-alpine
  ├── 安装 gcc/g++/musl-dev（CGO 依赖）
  ├── 下载 Go 依赖
  └── 编译 Linux AMD64 二进制文件

阶段3: runtime（可选）
  ├── 使用 alpine:latest
  ├── 复制前端和后端产物
  └── 创建可运行的容器镜像
```

### 手动 Docker 构建

```bash
# 仅构建 Linux 二进制
bash scripts/build-linux.sh

# 构建并运行完整镜像
docker build -f Dockerfile.build -t psd2img:latest .
docker run -p 4567:4567 -v $(pwd)/data:/app/db psd2img:latest
```

---

## 故障排查

### 错误: "call to undeclared function 'setresgid'"

**原因**: 在 macOS 上使用 `CGO_ENABLED=1` 交叉编译 Linux 时，遇到 Linux 特有的系统调用。

**解决**: 使用 `make build-prod`（Docker 构建）或 `make build-prod-local`（仅本地）。

### 错误: "undefined: webpGetInfo"

**原因**: 使用 `CGO_ENABLED=0` 时，CGO 绑定不可用。

**解决**: 必须使用 `CGO_ENABLED=1` 构建。

### Docker 构建慢

**优化**:
1. 使用国内镜像加速（Dockerfile 已配置 GOPROXY）
2. Docker 层缓存（依赖变化时才重新下载）
3. 使用 BuildKit: `export DOCKER_BUILDKIT=1`

---

## 推荐工作流

### 开发阶段
```bash
make build          # 快速本地构建
make run            # 运行服务
```

### 测试阶段
```bash
make build-prod-local    # 本地生产构建
./build/server-darwin-arm64
```

### 生产部署
```bash
make build-prod     # 完整多平台构建
# 或
make docker-build   # 构建 Docker 镜像
```

---

最后更新: 2025-12-12
