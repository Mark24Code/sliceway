# Sliceway

<p>
  <a href="README.md">中文版</a> |
  <a href="README_EN.md">English Version</a>
</p>
<div align="center">
  <img src="frontend/public/logo.svg" alt="Sliceway Logo" width="200" height="200">

  <p><em>现代化的 Photoshop 文件处理和导出工具</em></p>

  [![Ruby](https://img.shields.io/badge/Ruby-3.0+-red.svg)](https://www.ruby-lang.org/)
  [![React](https://img.shields.io/badge/React-18+-blue.svg)](https://reactjs.org/)
  [![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://www.docker.com/)
</div>

## 🚀 功能特性

### 核心功能
- **智能 PSD 解析**: 自动解析 Photoshop 文件中的图层、切片、组和文字
- **批量导出**: 支持多倍率导出 (1x, 2x, 4x)
- **项目管理**: 完整的项目生命周期管理
- **实时预览**: 图层预览和属性查看

### 高级特性
- **增量更新**: 基于内容哈希的智能导出，只导出有变化的内容
- **批量操作**: 支持批量选择、删除和导出
- **文件追踪**: 导出历史记录和文件变更检测
- **多格式支持**: 支持 PSD 和 PSB 文件格式

## 🛠️ 快速启动

### 使用预构建镜像

Linux/MacOS
```bash
# 从 Docker Hub 拉取并运行预构建镜像
docker run -d \
  -p 4567:4567 \
  -v /path/to/data:/data \
  mark24code/sliceway:latest
```

Windows

```cmd
docker run -d ^
  -p 4567:4567 ^
  -v "C:\path\to\exports:/data" ^
  mark24code/sliceway:latest
```


### 开发环境启动

#### 1. 一键初始化
```bash
# 安装所有依赖并初始化数据库
rake project:init
```

#### 2. 启动后端服务
```bash
# 启动 Sinatra 服务器 (端口 4567)
rake server:start
```

#### 3. 启动前端开发服务器
```bash
# 启动前端开发服务器 (端口 5173)
rake server:frontend
```

#### 4. 访问应用
- **前端界面**: http://localhost:5173
- **后端 API**: http://localhost:4567

### 生产环境启动

#### 构建前端
```bash
cd frontend
npm run build
```

#### 启动生产服务器
```bash
RACK_ENV=production bundle exec ruby app.rb
```

## 🐳 Docker 使用方法


### 构建镜像
```bash
docker build -t sliceway .
```

### 运行容器
```bash
docker run -d \
  --name sliceway \
  -p 4567:4567 \
  -v /path/to/data:/data \
  sliceway
```


### 数据持久化
- **上传文件**: `/data/uploads`
- **导出文件**: `/data/exports`
- **数据库**: `/data/db`
- **处理文件**: `/data/public/processed`

## 📖 使用方法

### 1. 创建项目
1. 打开前端界面
2. 点击 "新建项目" 按钮
3. 上传 PSD/PSB 文件
4. 设置项目名称和导出路径

### 2. 处理文件
- 系统自动解析 PSD 文件
- 查看解析出的图层、切片和组
- 支持按类型筛选和搜索

### 3. 导出图片
1. 选择需要导出的图层
2. 设置导出倍率 (1x, 2x, 4x)
3. 点击导出按钮
4. 导出的图片保存到指定目录

### 4. 批量操作
- 支持多项目批量删除
- 状态感知的确认对话框
- 实时进度显示

## 🔧 配置说明

### 环境变量
```bash
# 服务器配置
RACK_ENV=production
UPLOADS_PATH=/data/uploads
PUBLIC_PATH=/data/public
DB_PATH=/data/db/production.sqlite3
EXPORTS_PATH=/data/exports
STATIC_PATH=/app/dist
```

### 端口配置
- **后端服务**: 4567
- **前端开发**: 5173
- **Docker 容器**: 4567

## 📋 系统要求

### 开发环境
- Ruby 3.0+
- Node.js 18+
- SQLite3

### 生产环境
- Docker 20.10+
- 2GB+ 内存
- 10GB+ 磁盘空间

## 🐛 故障排除

### 常见问题
1. **端口冲突**: 检查 4567 和 5173 端口是否被占用
2. **文件权限**: 确保数据目录有读写权限
3. **内存不足**: 处理大文件时确保有足够内存

### 调试模式
```bash
DEBUG=true bundle exec ruby app.rb
```

---

<div align="center">
  <p>Made with ❤️ for designers and developers</p>
</div>
