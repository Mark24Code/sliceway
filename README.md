# Sliceway - Photoshop 文件处理和导出工具

这是一个基于 Ruby 和 React 的 PSD 文件处理和导出工具，支持切片、图层、文字和组的智能导出，具有增量更新和 Web 界面管理功能。

## 项目结构

```
Sliceway/
├── app.rb                 # Sinatra 后端主应用
├── Gemfile               # Ruby 依赖管理
├── lib/                  # 核心库文件
│   ├── database.rb       # 数据库配置和表结构
│   ├── models.rb         # ActiveRecord 模型
│   └── psd_processor.rb  # PSD 处理逻辑
├── frontend/             # React 前端应用
│   ├── package.json      # Node.js 依赖管理
│   ├── src/              # 前端源码
│   └── vite.config.ts    # Vite 配置
├── db/                   # 数据库文件
│   └── development.sqlite3
├── uploads/              # 上传的 PSD 文件
├── exports/              # 导出的图片文件
└── output/               # 脚本导出目录
```

## 功能特性

- ✅ **智能导出**: 支持切片、图层、组和文字图层的导出
- ✅ **增量更新**: 基于内容哈希的智能导出，只导出有变化的内容
- ✅ **Web 界面**: 基于 React + Ant Design 的现代化管理界面
- ✅ **项目管理**: 支持多项目管理和批量导出
- ✅ **实时进度**: 导出进度实时显示
- ✅ **文件追踪**: 导出历史记录和文件变更检测

## 快速开始

### 环境要求

- Ruby 3.0+
- Node.js 18+
- SQLite3

### 一键初始化

```bash
# 一键安装所有依赖并初始化数据库
rake project:init
```

### 启动应用

#### 启动后端服务

```bash
# 启动 Sinatra 服务器 (端口 4567)
rake server:start
```

#### 启动前端开发服务器

```bash
# 启动前端开发服务器 (端口 5173)
rake server:frontend
```

### 访问应用

- **前端界面**: http://localhost:5173
- **后端 API**: http://localhost:4567

## 使用方法

### 1. 上传 PSD 文件

1. 打开前端界面 (http://localhost:5173)
2. 点击 "新建项目" 按钮
3. 上传 PSD 文件
4. 系统会自动解析并处理文件

### 2. 查看和管理图层

- 在项目详情页查看所有解析出的图层
- 按类型筛选：切片、图层、组、文字
- 搜索图层名称
- 查看图层属性和预览图

### 3. 导出图片

1. 选择需要导出的图层
2. 点击 "导出选中" 按钮
3. 导出的图片会保存到项目的导出目录

## Rake 管理工具

项目使用 Rake 进行统一的项目管理，所有操作都可以通过 Rake 命令完成。

### 项目管理

```bash
# 初始化项目（安装所有依赖）
rake project:init

# 重置整个项目（清理所有数据）
rake project:reset

# 显示项目状态
rake project:status
```

### 数据库管理

```bash
# 初始化数据库结构
rake db:init

# 重置数据库并清理文件
rake db:reset

# 显示数据库状态
rake db:status
```

### 服务器管理

```bash
# 启动后端服务器
rake server:start

# 启动前端开发服务器
rake server:frontend
```

### 查看所有可用任务

```bash
# 显示所有 Rake 任务
rake -T

# 或直接运行默认任务
rake
```

### 命令行导出工具

项目还提供了一些独立的命令行导出工具：

```bash
# 导出切片
ruby export_slices.rb

# 导出图层组
ruby export_groups.rb

# 导出文字图层
ruby export_text_layers.rb

# 带元信息的导出
ruby export_slices_with_metadata.rb
```

## API 接口

### 项目管理

- `GET /api/projects` - 获取项目列表
- `POST /api/projects` - 创建新项目
- `GET /api/projects/:id` - 获取项目详情
- `DELETE /api/projects/:id` - 删除项目

### 图层管理

- `GET /api/projects/:id/layers` - 获取项目图层
  - 参数: `type` - 图层类型筛选
  - 参数: `q` - 名称搜索

### 导出功能

- `POST /api/projects/:id/export` - 导出选中图层

## 配置说明

### 数据库配置

数据库使用 SQLite3，配置文件在 `lib/database.rb`：

```ruby
ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: 'db/development.sqlite3'
)
```

### 服务器配置

后端服务器配置在 `app.rb`：

```ruby
set :public_folder, 'public'
set :bind, '0.0.0.0'
set :port, 4567
```

### 前端配置

前端开发服务器配置在 `frontend/vite.config.ts`：

```typescript
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api': 'http://localhost:4567'
    }
  }
})
```

## 开发说明

### 项目架构

- **后端**: Sinatra + ActiveRecord + SQLite3
- **前端**: React + TypeScript + Ant Design + Vite
- **PSD 处理**: 基于 psd.rb 库的 PSD 文件解析

### 核心组件

- `PsdProcessor` - PSD 文件解析和处理
- `ExportTracker` - 导出追踪和增量更新
- `Project` - 项目管理模型
- `Layer` - 图层数据模型

### 扩展开发

#### 添加新的导出类型

1. 在 `lib/psd_processor.rb` 中添加新的处理逻辑
2. 在 `export_tracker.rb` 中添加对应的哈希计算方法
3. 在前端界面中添加对应的类型筛选

#### 自定义导出路径

修改 `app.rb` 中的导出路径配置：

```ruby
project.export_path = params[:export_path] || File.join(Dir.pwd, "exports", "#{Time.now.to_i}")
```

## 故障排除

### 常见问题

1. **PSD 文件解析失败**
   - 确保 PSD 文件已启用兼容模式保存
   - 检查文件路径和权限

2. **前端无法连接后端**
   - 确认后端服务正在运行 (端口 4567)
   - 检查前端代理配置

3. **数据库错误**
   - 运行数据库重置脚本
   - 检查数据库文件权限

### 调试模式

启用调试模式查看详细日志：

```bash
# 设置环境变量
DEBUG=true ruby app.rb
```

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request！