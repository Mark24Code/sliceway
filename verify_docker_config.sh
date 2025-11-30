#!/bin/bash

# Sliceway Docker 配置验证脚本

echo "=========================================="
echo "Sliceway Docker 配置验证"
echo "=========================================="
echo ""

# 检查必要文件
echo "1️⃣  检查必要文件..."
files=(
    "Dockerfile"
    "start_docker.sh"
    "app.rb"
    "lib/psd_processor.rb"
    "lib/database.rb"
    "Rakefile"
    ".dockerignore"
)

all_files_ok=true
for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "   ✅ $file"
    else
        echo "   ❌ $file - 缺失"
        all_files_ok=false
    fi
done

if [ "$all_files_ok" = false ]; then
    echo ""
    echo "❌ 部分必要文件缺失，请检查！"
    exit 1
fi

echo ""
echo "2️⃣  检查脚本权限..."
if [ -x "start_docker.sh" ]; then
    echo "   ✅ start_docker.sh 有执行权限"
else
    echo "   ⚠️  start_docker.sh 没有执行权限"
    echo "   修复: chmod +x start_docker.sh"
fi

echo ""
echo "3️⃣  检查 Dockerfile 配置..."
if grep -q "COPY --from=frontend-builder /app/frontend/dist ./dist" Dockerfile; then
    echo "   ✅ 前端构建产物路径正确"
else
    echo "   ❌ 前端构建产物路径配置错误"
fi

if grep -q "ENV PUBLIC_PATH=/data/public" Dockerfile; then
    echo "   ✅ PUBLIC_PATH 环境变量正确"
else
    echo "   ❌ PUBLIC_PATH 环境变量配置错误"
fi

if grep -q "ENV STATIC_PATH=/app/dist" Dockerfile; then
    echo "   ✅ STATIC_PATH 环境变量正确"
else
    echo "   ❌ STATIC_PATH 环境变量配置错误"
fi

if grep -q "bundle exec rake db:migrate" Dockerfile; then
    echo "   ✅ 启动命令包含数据库迁移"
else
    echo "   ❌ 启动命令缺少数据库迁移"
fi

echo ""
echo "4️⃣  检查 app.rb 配置..."
if grep -q "ENV\['PUBLIC_PATH'\]" app.rb; then
    echo "   ✅ app.rb 使用 PUBLIC_PATH 环境变量"
else
    echo "   ❌ app.rb 未正确使用 PUBLIC_PATH 环境变量"
fi

if grep -q "ENV\['STATIC_PATH'\]" app.rb; then
    echo "   ✅ app.rb 使用 STATIC_PATH 环境变量"
else
    echo "   ❌ app.rb 未正确使用 STATIC_PATH 环境变量"
fi

echo ""
echo "5️⃣  检查 lib/psd_processor.rb 配置..."
if grep -q "ENV\['PUBLIC_PATH'\]" lib/psd_processor.rb; then
    echo "   ✅ psd_processor.rb 使用环境变量"
else
    echo "   ❌ psd_processor.rb 未正确使用环境变量"
fi

echo ""
echo "6️⃣  检查 Rakefile 配置..."
if grep -q "ENV\['DB_PATH'\]" Rakefile; then
    echo "   ✅ Rakefile 支持环境变量"
else
    echo "   ❌ Rakefile 未支持环境变量"
fi

if grep -q "task :migrate" Rakefile; then
    echo "   ✅ Rakefile 包含 migrate 任务"
else
    echo "   ❌ Rakefile 缺少 migrate 任务"
fi

echo ""
echo "7️⃣  检查 Docker 环境..."
if command -v docker &> /dev/null; then
    echo "   ✅ Docker 已安装"
    docker --version
else
    echo "   ❌ Docker 未安装"
    echo "   请安装 Docker: https://www.docker.com/get-started"
fi

echo ""
echo "=========================================="
echo "验证完成！"
echo "=========================================="
echo ""
echo "如果所有检查都通过，可以运行:"
echo "  ./start_docker.sh"
echo ""
echo "查看文档:"
echo "  cat DOCKER_README.md"
echo "  cat DOCKER_TEST_GUIDE.md"
echo ""
