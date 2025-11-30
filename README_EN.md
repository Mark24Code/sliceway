# Sliceway

<div align="center">
  <img src="frontend/public/logo.svg" alt="Sliceway Logo" width="200" height="200">

  <p><em>Modern Photoshop File Processing and Export Tool</em></p>

  [![Ruby](https://img.shields.io/badge/Ruby-3.0+-red.svg)](https://www.ruby-lang.org/)
  [![React](https://img.shields.io/badge/React-18+-blue.svg)](https://reactjs.org/)
  [![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://www.docker.com/)
</div>

## 🚀 Features

### Core Features
- **Smart PSD Parsing**: Automatically parse layers, slices, groups, and text from Photoshop files
- **Batch Export**: Support multi-scale exports (1x, 2x, 4x)
- **Project Management**: Complete project lifecycle management
- **Real-time Preview**: Layer preview and property viewing

### Advanced Features
- **Incremental Updates**: Smart export based on content hash, only exporting changed content
- **Batch Operations**: Support batch selection, deletion, and export
- **File Tracking**: Export history and file change detection
- **Multi-format Support**: Support for PSD and PSB file formats

## 🛠️ Quick Start

### Development Environment Setup

#### 1. One-click Initialization
```bash
# Install all dependencies and initialize database
rake project:init
```

#### 2. Start Backend Service
```bash
# Start Sinatra server (port 4567)
rake server:start
```

#### 3. Start Frontend Development Server
```bash
# Start frontend development server (port 5173)
rake server:frontend
```

#### 4. Access Application
- **Frontend Interface**: http://localhost:5173
- **Backend API**: http://localhost:4567

### Production Environment Setup

#### Build Frontend
```bash
cd frontend
npm run build
```

#### Start Production Server
```bash
RACK_ENV=production bundle exec ruby app.rb
```

## 🐳 Docker Usage

### Using Pre-built Image
```bash
# Pull and run the pre-built image from Docker Hub
docker run -d \
  -p 4567:4567 \
  -v /path/to/data:/data \
  mark24code/sliceway:latest
```

### Build Image
```bash
docker build -t sliceway:1.0.0 -t sliceway:latest .
```

### Run Container
```bash
docker run -d \
  --name sliceway \
  -p 4567:4567 \
  -v /path/to/data:/data \
  sliceway:latest
```


### Data Persistence
- **Uploaded Files**: `/data/uploads`
- **Exported Files**: `/data/exports`
- **Database**: `/data/db`
- **Processed Files**: `/data/public/processed`

## 📖 Usage Guide

### 1. Create Project
1. Open the frontend interface
2. Click "New Project" button
3. Upload PSD/PSB file
4. Set project name and export path

### 2. Process Files
- System automatically parses PSD files
- View parsed layers, slices, and groups
- Support filtering and search by type

### 3. Export Images
1. Select layers to export
2. Set export scales (1x, 2x, 4x)
3. Click export button
4. Exported images saved to specified directory

### 4. Batch Operations
- Support multi-project batch deletion
- Status-aware confirmation dialogs
- Real-time progress display

## 🔧 Configuration

### Environment Variables
```bash
# Server Configuration
RACK_ENV=production
UPLOADS_PATH=/data/uploads
PUBLIC_PATH=/data/public
DB_PATH=/data/db/production.sqlite3
EXPORTS_PATH=/data/exports
STATIC_PATH=/app/dist
```

### Port Configuration
- **Backend Service**: 4567
- **Frontend Development**: 5173
- **Docker Container**: 4567

## 📋 System Requirements

### Development Environment
- Ruby 3.0+
- Node.js 18+
- SQLite3

### Production Environment
- Docker 20.10+
- 2GB+ RAM
- 10GB+ Disk Space

## 🐛 Troubleshooting

### Common Issues
1. **Port Conflicts**: Check if ports 4567 and 5173 are occupied
2. **File Permissions**: Ensure data directories have read/write permissions
3. **Insufficient Memory**: Ensure enough memory when processing large files

### Debug Mode
```bash
DEBUG=true bundle exec ruby app.rb
```

---

<div align="center">
  <p>Made with ❤️ for designers and developers</p>

  <p>
    <a href="README.md">中文版</a> |
    <a href="README_EN.md">English Version</a>
  </p>
</div>
