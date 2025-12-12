# PSD 库切换说明

## 变更内容

已从使用本地 `psd/` 目录切换到直接使用 GitHub 远程库。

### 之前（本地库）
```go
// go.mod
replace github.com/Mark24Code/psd => ./psd
```

### 现在（远程库）
```go
// go.mod
require (
    github.com/Mark24Code/psd v0.0.0-20251212032139-a03fd0cb2d10
    ...
)
```

## 优点

1. ✅ **无需本地目录** - 不需要维护 `psd/` 目录
2. ✅ **自动版本管理** - Go modules 自动管理依赖
3. ✅ **简化部署** - 构建时自动下载依赖
4. ✅ **官方更新** - 直接使用 GitHub 上的最新代码

## 使用方法

### 安装依赖
```bash
export GOPROXY=https://goproxy.cn,direct
go mod download
```

### 构建
```bash
make backend
# 或
go build -o server ./cmd/server
```

### 更新 PSD 库
```bash
# 更新到最新版本
go get -u github.com/Mark24Code/psd

# 或指定版本
go get github.com/Mark24Code/psd@latest
```

## 注意事项

- ✅ 代码中的 import 语句保持不变：`import "github.com/Mark24Code/psd"`
- ✅ PSD 库功能完全相同，无需修改业务代码
- ✅ 已测试构建和运行，一切正常

## 测试结果

```bash
$ make backend
>>> 构建后端...
✓ 后端构建完成: ./server

$ ./server
2025/12/12 12:45:23 Database initialized successfully
2025/12/12 12:45:23 Starting server on 0.0.0.0:4567
[GIN-debug] Listening and serving HTTP on 0.0.0.0:4567

$ curl http://localhost:4567/api/version
{"description":"现代化的 Photoshop 文件处理和导出工具","name":"Sliceway","version":"dev"}
```

## 移除本地 psd 目录

现在可以安全删除本地 `psd/` 目录：

```bash
rm -rf psd/
```

---

**切换完成！现在使用 GitHub 官方 PSD 库！** ✅
