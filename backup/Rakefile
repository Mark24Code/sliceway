#!/usr/bin/env rake
# Sliceway 项目管理脚本
# 使用: rake <task_name>

require 'fileutils'
require 'sqlite3'
require 'active_record'

# 项目配置 - 从环境变量获取，支持生产环境
DATABASE_PATH = ENV['DB_PATH'] || 'db/development.sqlite3'
UPLOADS_DIR = ENV['UPLOADS_PATH'] || 'uploads'
EXPORTS_DIR = ENV['EXPORTS_PATH'] || 'exports'
PUBLIC_DIR = ENV['PUBLIC_PATH'] || 'public'

namespace :db do
  desc "运行数据库迁移（生产环境安全）"
  task :migrate do
    puts "=== Sliceway 数据库迁移 ==="
    puts "数据库路径: #{DATABASE_PATH}"
    puts ""

    # 确保数据库目录存在
    db_dir = File.dirname(DATABASE_PATH)
    FileUtils.mkdir_p(db_dir) unless Dir.exist?(db_dir)

    # 确保必要的目录存在
    [UPLOADS_DIR, EXPORTS_DIR, PUBLIC_DIR].each do |dir|
      FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
    end

    # 创建 processed 子目录
    processed_dir = File.join(PUBLIC_DIR, 'processed')
    FileUtils.mkdir_p(processed_dir) unless Dir.exist?(processed_dir)

    puts "✅ 目录结构已准备"

    # 加载数据库配置（会自动创建表）
    require_relative 'lib/database'

    puts "✅ 数据库迁移完成"
  end

  desc "初始化数据库结构"
  task :init do
    puts "=== Sliceway 数据库初始化 ==="
    puts ""

    # 检查数据库文件是否存在
    if File.exist?(DATABASE_PATH)
      puts "📊 当前数据库状态:"
      puts "   数据库文件: #{DATABASE_PATH}"
      puts "   文件大小: #{File.size(DATABASE_PATH)} 字节"

      # 检查数据库表结构
      begin
        ActiveRecord::Base.establish_connection(
          adapter: 'sqlite3',
          database: DATABASE_PATH
        )

        tables_exist = true
        required_tables = ['projects', 'layers']

        required_tables.each do |table|
          exists = ActiveRecord::Base.connection.table_exists?(table)
          status = exists ? "✅ 存在" : "❌ 缺失"
          puts "   表 #{table}: #{status}"
          tables_exist &&= exists
        end

        if tables_exist
          puts ""
          puts "ℹ️  数据库表结构完整，无需初始化"
          exit 0
        end

      rescue => e
        puts "   ⚠️  无法读取数据库信息: #{e.message}"
        puts "   数据库文件可能已损坏，将重新创建"
      end
    else
      puts "📊 数据库文件不存在，将创建新数据库"
    end

    puts ""

    # 执行初始化操作
    puts "🔄 正在初始化数据库..."

    # 确保db目录存在
    FileUtils.mkdir_p('db')

    # 备份现有数据库（如果存在）
    if File.exist?(DATABASE_PATH)
      backup_path = "db/development.sqlite3.backup.#{Time.now.to_i}"
      FileUtils.cp(DATABASE_PATH, backup_path)
      puts "   ✅ 数据库已备份到: #{backup_path}"
    end

    # 删除现有数据库文件
    if File.exist?(DATABASE_PATH)
      File.delete(DATABASE_PATH)
      puts "   ✅ 旧数据库文件已删除"
    end

    # 重新创建数据库
    begin
      require_relative 'lib/database'
      puts "   ✅ 数据库连接已建立"

      # 验证表结构
      puts "   🔍 验证表结构..."

      required_tables = ['projects', 'layers']
      required_tables.each do |table|
        if ActiveRecord::Base.connection.table_exists?(table)
          puts "     表 #{table}: ✅ 创建成功"
        else
          puts "     表 #{table}: ❌ 创建失败"
        end
      end

      # 创建必要的目录
      puts ""
      puts "📁 创建必要目录..."

      required_dirs = [UPLOADS_DIR, EXPORTS_DIR, PUBLIC_DIR]
      required_dirs.each do |dir|
        if Dir.exist?(dir)
          puts "   #{dir}/: ✅ 已存在"
        else
          FileUtils.mkdir_p(dir)
          puts "   #{dir}/: ✅ 已创建"
        end
      end

      puts ""
      puts "✅ 数据库初始化完成！"

    rescue => e
      puts "❌ 数据库初始化失败: #{e.message}"
      puts e.backtrace.join("\n") if ENV['DEBUG']
      exit 1
    end
  end

  desc "重置数据库并清理文件"
  task :reset do
    puts "=== Sliceway 数据库重置 ==="
    puts ""

    # 检查数据库文件是否存在
    if File.exist?(DATABASE_PATH)
      puts "📊 当前数据库信息:"
      puts "   数据库文件: #{DATABASE_PATH}"
      puts "   文件大小: #{File.size(DATABASE_PATH)} 字节"

      # 连接到数据库获取统计信息
      begin
        ActiveRecord::Base.establish_connection(
          adapter: 'sqlite3',
          database: DATABASE_PATH
        )

        if ActiveRecord::Base.connection.table_exists?(:projects)
          project_count = ActiveRecord::Base.connection.execute("SELECT COUNT(*) FROM projects").first[0]
          layer_count = ActiveRecord::Base.connection.execute("SELECT COUNT(*) FROM layers").first[0]

          puts "   项目数量: #{project_count}"
          puts "   图层数量: #{layer_count}"
        else
          puts "   数据库表不存在，需要初始化"
        end
      rescue => e
        puts "   ⚠️  无法读取数据库信息: #{e.message}"
      end
    else
      puts "📊 数据库文件不存在，将创建新数据库"
    end

    puts ""

    # 检查目录结构
    puts "📁 目录结构检查:"

    [UPLOADS_DIR, EXPORTS_DIR, PUBLIC_DIR].each do |dir|
      if Dir.exist?(dir)
        file_count = Dir.glob(File.join(dir, "**", "*")).count { |file| File.file?(file) }
        puts "   #{dir}/ - 存在 (#{file_count} 个文件)"
      else
        puts "   #{dir}/ - 不存在"
      end
    end

    puts ""

    # 确认操作 - 在非交互式环境中自动确认
    puts "⚠️  确定要重置数据库吗？这将删除所有项目数据和导出记录"

    # # 检查是否在交互式环境中
    # if STDIN.tty? && STDOUT.tty?
    #   print "   输入 'yes' 继续: "
    #   confirmation = gets.chomp.downcase

    #   unless confirmation == 'yes'
    #     puts "❌ 操作已取消"
    #     exit 0
    #   end
    # else
    #   puts "   ⚠️  非交互式环境，自动确认重置操作"
    # end

    puts ""

    # 执行重置操作
    puts "🔄 正在重置数据库..."

    # 备份数据库（如果存在）
    if File.exist?(DATABASE_PATH)
      backup_path = "db/development.sqlite3.backup.#{Time.now.to_i}"
      FileUtils.cp(DATABASE_PATH, backup_path)
      puts "   ✅ 数据库已备份到: #{backup_path}"
    end

    # 删除数据库文件
    if File.exist?(DATABASE_PATH)
      File.delete(DATABASE_PATH)
      puts "   ✅ 数据库文件已删除"
    end

    # 重新创建数据库
    require_relative 'lib/database'
    puts "   ✅ 新数据库已创建"

    puts ""

    # 清理导出目录
    puts "🗑️  清理导出目录..."
    if Dir.exist?(EXPORTS_DIR)
      FileUtils.rm_rf(Dir.glob(File.join(EXPORTS_DIR, "*")))
      puts "   ✅ 导出目录已清理"
    else
      puts "   ℹ️  导出目录不存在，无需清理"
    end

    # 清理上传目录
    puts "🗑️  清理上传目录..."
    if Dir.exist?(UPLOADS_DIR)
      FileUtils.rm_rf(Dir.glob(File.join(UPLOADS_DIR, "*")))
      puts "   ✅ 上传目录已清理"
    else
      puts "   ℹ️  上传目录不存在，无需清理"
    end

    # 清理公共目录中的图片文件
    puts "🗑️  清理公共目录中的图片文件..."
    if Dir.exist?(PUBLIC_DIR)
      # 只删除图片文件，保留其他必要的静态文件
      image_extensions = ['.png', '.jpg', '.jpeg', '.gif', '.bmp']
      image_files = Dir.glob(File.join(PUBLIC_DIR, "**", "*{#{image_extensions.join(',')}}"))

      if image_files.any?
        image_files.each { |file| File.delete(file) if File.exist?(file) }
        puts "   ✅ 已删除 #{image_files.size} 个图片文件"
      else
        puts "   ℹ️  公共目录中没有图片文件"
      end
    else
      puts "   ℹ️  公共目录不存在，无需清理"
    end

    puts ""
    puts "✅ 数据库重置完成！"
  end

  desc "显示数据库状态"
  task :status do
    puts "=== Sliceway 数据库状态 ==="
    puts ""

    if File.exist?(DATABASE_PATH)
      puts "📊 数据库信息:"
      puts "   文件路径: #{DATABASE_PATH}"
      puts "   文件大小: #{File.size(DATABASE_PATH)} 字节"

      begin
        ActiveRecord::Base.establish_connection(
          adapter: 'sqlite3',
          database: DATABASE_PATH
        )

        if ActiveRecord::Base.connection.table_exists?(:projects)
          project_count = ActiveRecord::Base.connection.execute("SELECT COUNT(*) FROM projects").first[0]
          layer_count = ActiveRecord::Base.connection.execute("SELECT COUNT(*) FROM layers").first[0]

          puts "   项目数量: #{project_count}"
          puts "   图层数量: #{layer_count}"
        else
          puts "   ⚠️  数据库表不存在"
        end
      rescue => e
        puts "   ⚠️  无法读取数据库信息: #{e.message}"
      end
    else
      puts "❌ 数据库文件不存在"
    end

    puts ""
    puts "📁 目录状态:"

    [UPLOADS_DIR, EXPORTS_DIR, PUBLIC_DIR].each do |dir|
      if Dir.exist?(dir)
        file_count = Dir.glob(File.join(dir, "**", "*")).count { |file| File.file?(file) }
        puts "   #{dir}/ - 存在 (#{file_count} 个文件)"
      else
        puts "   #{dir}/ - 不存在"
      end
    end
  end
end

namespace :server do
  desc "启动后端服务器"
  task :start do
    puts "=== 启动 Sliceway 后端服务器 ==="
    puts ""
    puts "🚀 启动 Sinatra 服务器 (端口 4567)..."
    puts "   访问地址: http://localhost:4567"
    puts ""
    puts "按 Ctrl+C 停止服务器"
    puts ""

    # 检查数据库
    unless File.exist?(DATABASE_PATH)
      puts "⚠️  数据库不存在，正在初始化..."
      Rake::Task['db:init'].invoke
    end

    # 启动服务器
    exec "ruby app.rb"
  end

  desc "启动前端开发服务器"
  task :frontend do
    puts "=== 启动 Sliceway 前端开发服务器 ==="
    puts ""
    puts "🚀 启动 Vite 开发服务器 (端口 5173)..."
    puts "   访问地址: http://localhost:5173"
    puts ""
    puts "按 Ctrl+C 停止服务器"
    puts ""

    # 检查前端依赖
    unless File.exist?("frontend/node_modules")
      puts "⚠️  前端依赖未安装，正在安装..."
      system "cd frontend && npm install"
    end

    # 启动前端服务器
    exec "cd frontend && npm run dev"
  end
end

namespace :project do
  desc "初始化项目（安装依赖）"
  task :init do
    puts "=== Sliceway 项目初始化 ==="
    puts ""

    # 安装后端依赖
    puts "📦 安装 Ruby 依赖..."
    if system "bundle install"
      puts "   ✅ Ruby 依赖安装完成"
    else
      puts "   ❌ Ruby 依赖安装失败"
      exit 1
    end

    puts ""

    # 安装前端依赖
    puts "📦 安装 Node.js 依赖..."
    if system "cd frontend && npm install"
      puts "   ✅ Node.js 依赖安装完成"
    else
      puts "   ❌ Node.js 依赖安装失败"
      exit 1
    end

    puts ""

    # 初始化数据库
    puts "🗄️  初始化数据库..."
    Rake::Task['db:init'].invoke

    puts ""
    puts "✅ 项目初始化完成！"
    puts ""
    puts "🎯 下一步操作:"
    puts "   启动后端: rake server:start"
    puts "   启动前端: rake server:frontend"
    puts "   查看状态: rake db:status"
  end

  desc "重置整个项目（清理所有数据）"
  task :reset do
    puts "=== Sliceway 项目重置 ==="
    puts ""

    # 确认操作 - 在非交互式环境中自动确认
    puts "⚠️  确定要重置整个项目吗？这将删除所有数据"

    # # 检查是否在交互式环境中
    # if STDIN.tty? && STDOUT.tty?
    #   print "   输入 'yes' 继续: "
    #   confirmation = gets.chomp.downcase

    #   unless confirmation == 'yes'
    #     puts "❌ 操作已取消"
    #     exit 0
    #   end
    # else
    #   puts "   ⚠️  非交互式环境，自动确认重置操作"
    # end

    # puts ""

    # 重置数据库
    Rake::Task['db:reset'].invoke

    puts ""
    puts "✅ 项目重置完成！"
  end

  desc "显示项目状态"
  task :status do
    puts "=== Sliceway 项目状态 ==="
    puts ""

    # 检查后端依赖
    puts "📦 后端依赖:"
    if File.exist?("Gemfile.lock")
      puts "   ✅ Gemfile.lock 存在"
    else
      puts "   ⚠️  Gemfile.lock 不存在，需要运行 'bundle install'"
    end

    # 检查前端依赖
    puts "📦 前端依赖:"
    if File.exist?("frontend/node_modules")
      puts "   ✅ node_modules 存在"
    else
      puts "   ⚠️  node_modules 不存在，需要运行 'cd frontend && npm install'"
    end

    puts ""

    # 显示数据库状态
    Rake::Task['db:status'].invoke
  end
end

# 默认任务
desc "显示所有可用任务"
task :default do
  puts "=== Sliceway 项目管理工具 ==="
  puts ""
  puts "📋 可用任务:"
  puts ""
  puts "🔧 项目管理:"
  puts "  rake project:init     - 初始化项目（安装依赖）"
  puts "  rake project:reset    - 重置整个项目（清理所有数据）"
  puts "  rake project:status   - 显示项目状态"
  puts ""
  puts "🗄️  数据库管理:"
  puts "  rake db:init          - 初始化数据库结构"
  puts "  rake db:reset         - 重置数据库并清理文件"
  puts "  rake db:status        - 显示数据库状态"
  puts ""
  puts "🚀 服务器管理:"
  puts "  rake server:start     - 启动后端服务器"
  puts "  rake server:frontend  - 启动前端开发服务器"
  puts ""
  puts "💡 快速开始:"
  puts "  1. rake project:init   # 初始化项目"
  puts "  2. rake server:start   # 启动后端"
  puts "  3. rake server:frontend # 启动前端"
  puts ""
  puts "📖 查看详细说明: rake -T"
end