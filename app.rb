require 'sinatra'
require 'sinatra/json'
require 'rack/cors'
require 'fileutils'
require_relative 'lib/database'
require_relative 'lib/models'
require_relative 'lib/psd_processor'
require_relative 'lib/version'
require 'json'

set :bind, '0.0.0.0'
set :port, 4567

# Helper method to get public path
def public_path
  ENV['PUBLIC_PATH'] || 'public'
end

use Rack::Cors do
  allow do
    origins '*'
    resource '*', headers: :any, methods: [:get, :post, :delete, :put, :options], expose: ['location', 'link']
  end
end

# Environment-aware static file serving configuration
# 环境感知的静态文件服务配置
static_path = ENV['STATIC_PATH'] || 'dist'

# Detect environment - production in Docker, development otherwise
# 检测环境 - Docker中为生产环境，其他情况为开发环境
production_env = ENV['RACK_ENV'] == 'production' || File.exist?('/.dockerenv')

# Serve processed files from PUBLIC_PATH via /processed path in both environments
# 在两种环境中都通过/processed路径从PUBLIC_PATH服务处理后的文件
public_path = ENV['PUBLIC_PATH'] || 'public'

# Custom route for processed files
# 为processed文件添加自定义路由
get '/processed/*' do
  filename = params[:splat].first
  file_path = File.join(File.expand_path(public_path), 'processed', filename)

  puts "DEBUG: Looking for processed file: #{file_path}"
  puts "DEBUG: File exists: #{File.exist?(file_path)}"

  if File.exist?(file_path)
    send_file file_path
  else
    status 404
    "File not found: #{file_path}"
  end
end

if production_env
  # Production environment (Docker): Serve static files from multiple sources
  # 生产环境(Docker): 从多个来源服务静态文件

  # Serve frontend assets from STATIC_PATH
  # 从STATIC_PATH服务前端资源
  set :public_folder, static_path
else
  # Development environment: Keep frontend-backend separation
  # 开发环境: 保持前后端分离
  set :public_folder, ENV['PUBLIC_PATH'] || 'public'

  # Serve frontend static assets (JS/CSS) from STATIC_PATH via /assets path
  # 通过/assets路径从STATIC_PATH服务前端静态资源(JS/CSS)
  use Rack::Static, :urls => ["/assets"], :root => static_path
end

# SPA Catch-all route
# Must be last to avoid overriding API routes
get '/' do
  static_path = ENV['STATIC_PATH'] || 'dist'
  send_file File.join(static_path, 'index.html')
end

get '*' do
  pass if request.path_info.start_with?('/api')
  pass if request.path_info.start_with?('/processed')

  # Serve index.html for SPA routing
  static_path = ENV['STATIC_PATH'] || 'dist'
  send_file File.join(static_path, 'index.html')
end

# System Info
get '/api/version' do
  json({
    version: Sliceway::VERSION,
    name: 'Sliceway',
    description: '现代化的 Photoshop 文件处理和导出工具'
  })
end

# Projects
get '/api/projects' do
  page = (params[:page] || 1).to_i
  per_page = 20
  projects = Project.order(created_at: :desc).offset((page - 1) * per_page).limit(per_page)
  json projects: projects, total: Project.count
end

post '/api/projects' do
  # Expect multipart form data
  if params[:file] && params[:file][:tempfile]
    filename = params[:file][:filename]
    if filename
      filename.force_encoding('UTF-8')
      unless filename.valid_encoding?
        filename.encode!('UTF-8', invalid: :replace, undef: :replace, replace: '?')
      end
    end
    # Save file to uploads
    upload_dir = ENV['UPLOADS_PATH'] || File.join("uploads")
    FileUtils.mkdir_p(upload_dir)
    target_path = File.join(upload_dir, "#{Time.now.to_i}_#{filename}")
    File.open(target_path, 'wb') do |f|
      f.write(params[:file][:tempfile].read)
    end

    # 处理导出路径：如果是相对路径，转换为绝对路径
    export_path = if params[:export_path]
      if params[:export_path].start_with?('/')
        params[:export_path] # 已经是绝对路径
      else
        File.join(Dir.pwd, params[:export_path]) # 相对路径转绝对路径
      end
    else
      base_export_path = ENV['EXPORTS_PATH'] || File.join(Dir.pwd, "exports")
      File.join(base_export_path, "#{Time.now.to_i}") # 默认路径
    end

    project = Project.create!(
      name: params[:name] || filename,
      psd_path: File.absolute_path(target_path), # Store absolute path
      export_path: export_path,
      export_scales: params[:export_scales] ? JSON.parse(params[:export_scales]) : ['1x'],
      status: 'pending'
    )

    # Trigger processing in a separate process
    pid = spawn("bundle exec ruby bin/process_psd #{project.id}")
    Process.detach(pid) # Avoid zombie processes

    # 保存任务PID到全局变量
    $running_tasks[project.id] = pid

    json project
  else
    status 400
    json error: "No file uploaded"
  end
end

get '/api/projects/:id' do
  project = Project.find(params[:id])
  json project
end

post '/api/projects/:id/process' do
  project = Project.find(params[:id])

  # 如果项目状态不是pending，则不允许重新处理
  if project.status != 'pending'
    status 400
    return json error: "项目状态为 #{project.status}，无法重新处理"
  end

  # 更新项目状态为处理中
  project.update(status: 'processing')

  # 在后台进程中处理PSD文件
  pid = spawn("bundle exec ruby bin/process_psd #{project.id}")
  Process.detach(pid)

  # 保存任务PID到全局变量
  $running_tasks[project.id] = pid

  json success: true
end

# 停止处理项目
post '/api/projects/:id/stop' do
  project = Project.find(params[:id])

  # 只有正在处理中的项目才能停止
  if project.status != 'processing'
    status 400
    return json error: "项目状态为 #{project.status}，无法停止处理"
  end

  # 中止对应的处理任务
  if $running_tasks[project.id]
    begin
      Process.kill("TERM", $running_tasks[project.id])
      puts "中止了项目 #{project.id} 的处理任务 (PID: #{$running_tasks[project.id]})"
    rescue Errno::ESRCH
      puts "进程 #{$running_tasks[project.id]} 不存在"
    end
    $running_tasks.delete(project.id)
  end

  # 清理已生成的文件
  begin
    # Clean up exported images in public directory
    public_path = ENV['PUBLIC_PATH'] || 'public'
    project.layers.each do |layer|
      if layer.image_path && File.exist?(File.join(public_path, layer.image_path))
        FileUtils.rm_rf(File.join(public_path, layer.image_path))
      end
    end

    # Clean up processed images directory
    processed_dir = File.join(public_path, 'processed', project.id.to_s)
    if Dir.exist?(processed_dir)
      FileUtils.rm_rf(processed_dir)
    end

    # 重置项目状态为初始状态
    project.update(status: 'pending')

    # 删除已生成的图层记录
    project.layers.destroy_all

  rescue => e
    puts "Warning: Failed to clean up some files: #{e.message}"
    status 500
    return json error: "停止处理时清理文件失败: #{e.message}"
  end

  json success: true
end

# System
get '/api/system/directories' do
  current_path = params[:path] || Dir.pwd

  # Security check: prevent going above root (though for this tool we might want full access)
  # For now, we trust the user as this is a local tool.

  begin
    # Normalize path
    current_path = File.absolute_path(current_path)

    # Get parent path
    parent_path = File.dirname(current_path)

    # List directories
    entries = Dir.entries(current_path).select do |entry|
      next false if entry == '.' || entry == '..'
      path = File.join(current_path, entry)
      File.directory?(path) && File.readable?(path)
    end.sort

    json({
      current_path: current_path,
      parent_path: parent_path,
      directories: entries,
      sep: File::SEPARATOR
    })
  rescue => e
    status 500
    json error: "Failed to list directories: #{e.message}"
  end
end

# 全局变量来跟踪正在运行的任务
$running_tasks = {}

delete '/api/projects/batch' do
  content_type :json

  begin
    ids = JSON.parse(request.body.read)['ids']

    if ids.nil? || !ids.is_a?(Array) || ids.empty?
      status 400
      return { error: 'Invalid project IDs' }.to_json
    end

    deleted_count = 0
    errors = []

    ids.each do |id|
      begin
        project = Project.find(id)

        # 根据项目状态执行不同的清理逻辑
        case project.status
        when 'processing'
          # 如果项目正在处理中，先中止后台任务
          puts "项目 #{project.id} 正在处理中，先中止处理任务..."
          if $running_tasks[project.id]
            begin
              Process.kill("TERM", $running_tasks[project.id])
              puts "已中止项目 #{project.id} 的处理任务 (PID: #{$running_tasks[project.id]})"
            rescue Errno::ESRCH
              puts "进程 #{$running_tasks[project.id]} 不存在"
            end
            $running_tasks.delete(project.id)
          end

        when 'ready'
          # 如果项目已完成，清理所有生成的文件
          puts "项目 #{project.id} 已完成，清理生成的文件..."

        when 'pending', 'error'
          # 如果项目待处理或出错，清理基础文件
          puts "项目 #{project.id} 状态为 #{project.status}，清理相关文件..."
        end

        # 清理所有相关文件
        begin
          # Clean up uploaded PSD file
          if project.psd_path && File.exist?(project.psd_path)
            FileUtils.rm_rf(project.psd_path)
            puts "已清理PSD文件: #{project.psd_path}"
          end

          # Clean up export directory
          if project.export_path && Dir.exist?(project.export_path)
            FileUtils.rm_rf(project.export_path)
            puts "已清理导出目录: #{project.export_path}"
          end

          # Clean up exported images in public directory
          public_path = ENV['PUBLIC_PATH'] || 'public'
          project.layers.each do |layer|
            if layer.image_path && File.exist?(File.join(public_path, layer.image_path))
              FileUtils.rm_rf(File.join(public_path, layer.image_path))
              puts "已清理图层图片: #{layer.image_path}"
            end
          end

          # Clean up processed images directory
          processed_dir = File.join(public_path, 'processed', project.id.to_s)
          if Dir.exist?(processed_dir)
            FileUtils.rm_rf(processed_dir)
            puts "已清理处理图片目录: #{processed_dir}"
          end

          puts "项目 #{project.id} 文件清理完成"

        rescue => e
          puts "Warning: Failed to clean up some files: #{e.message}"
        end

        # 删除项目记录
        project.destroy
        puts "项目 #{project.id} 记录已删除"
        deleted_count += 1

      rescue ActiveRecord::RecordNotFound
        errors << "Project #{id} not found"
      rescue => e
        errors << "Failed to delete project #{id}: #{e.message}"
      end
    end

    if errors.any?
      {
        success: false,
        deleted_count: deleted_count,
        errors: errors
      }.to_json
    else
      {
        success: true,
        deleted_count: deleted_count,
        message: "Successfully deleted #{deleted_count} projects"
      }.to_json
    end

  rescue JSON::ParserError
    status 400
    { error: 'Invalid JSON format' }.to_json
  end
end

delete '/api/projects/:id' do
  project = Project.find(params[:id])

  # 根据项目状态执行不同的清理逻辑
  case project.status
  when 'processing'
    # 如果项目正在处理中，先中止后台任务
    puts "项目 #{project.id} 正在处理中，先中止处理任务..."
    if $running_tasks[project.id]
      begin
        Process.kill("TERM", $running_tasks[project.id])
        puts "已中止项目 #{project.id} 的处理任务 (PID: #{$running_tasks[project.id]})"
      rescue Errno::ESRCH
        puts "进程 #{$running_tasks[project.id]} 不存在"
      end
      $running_tasks.delete(project.id)
    end

  when 'ready'
    # 如果项目已完成，清理所有生成的文件
    puts "项目 #{project.id} 已完成，清理生成的文件..."

  when 'pending', 'error'
    # 如果项目待处理或出错，清理基础文件
    puts "项目 #{project.id} 状态为 #{project.status}，清理相关文件..."
  end

  # 清理所有相关文件
  begin
    # Clean up uploaded PSD file
    if project.psd_path && File.exist?(project.psd_path)
      FileUtils.rm_rf(project.psd_path)
      puts "已清理PSD文件: #{project.psd_path}"
    end

    # Clean up export directory
    if project.export_path && Dir.exist?(project.export_path)
      FileUtils.rm_rf(project.export_path)
      puts "已清理导出目录: #{project.export_path}"
    end

    # Clean up exported images in public directory
    public_path = ENV['PUBLIC_PATH'] || 'public'
    project.layers.each do |layer|
      if layer.image_path && File.exist?(File.join(public_path, layer.image_path))
        FileUtils.rm_rf(File.join(public_path, layer.image_path))
        puts "已清理图层图片: #{layer.image_path}"
      end
    end

    # Clean up processed images directory
    processed_dir = File.join(public_path, 'processed', project.id.to_s)
    if Dir.exist?(processed_dir)
      FileUtils.rm_rf(processed_dir)
      puts "已清理处理图片目录: #{processed_dir}"
    end

    puts "项目 #{project.id} 文件清理完成"

  rescue => e
    puts "Warning: Failed to clean up some files: #{e.message}"
  end

  # 删除项目记录
  project.destroy
  puts "项目 #{project.id} 记录已删除"

  json success: true
end

# Layers
get '/api/projects/:id/layers' do
  project = Project.find(params[:id])
  layers = project.layers

  if params[:type] && !params[:type].empty?
    layers = layers.where(layer_type: params[:type])
  end

  if params[:q] && !params[:q].empty?
    layers = layers.where("name LIKE ?", "%#{params[:q]}%")
  end

  json layers
end

# Export
post '/api/projects/:id/export' do
  project = Project.find(params[:id])
  data = JSON.parse(request.body.read)
  layer_ids = data['layer_ids']
  renames = data['renames'] || {}
  clear_directory = data['clear_directory'] || false
  puts "DEBUG: Exporting layers #{layer_ids}"
  puts "DEBUG: Renames received: #{renames.inspect}"
  puts "DEBUG: Clear directory: #{clear_directory}"

  layers = project.layers.where(id: layer_ids)
  export_count = 0

  if clear_directory && File.directory?(project.export_path)
    puts "DEBUG: Clearing directory #{project.export_path}"
    # Remove all files in the directory, but keep the directory itself
    FileUtils.rm_rf(Dir.glob(File.join(project.export_path, '*')))
  end

  FileUtils.mkdir_p(project.export_path)

  requested_scales = data['scales'] || ['1x']

  layers.each do |layer|
    next unless layer.image_path

    # Get base path and extension
    # image_path is like "processed/1/layer_123.png"
    # We need to find variants like "processed/1/layer_123@2x.png"

    public_path = ENV['PUBLIC_PATH'] || 'public'
    base_source = File.join(public_path, layer.image_path)
    ext = File.extname(base_source)
    base_name_without_ext = File.basename(base_source, ext)
    dir_name = File.dirname(base_source)

    # Determine target base name
    # If renamed, use new name directly. Otherwise use default format.
    if renames[layer.id.to_s] && !renames[layer.id.to_s].empty?
      target_base_name = renames[layer.id.to_s]
    else
      target_base_name = "#{layer.name}_#{layer.id}"
    end

    requested_scales.each do |scale|
      # Determine source filename for this scale
      if scale == '1x'
        source = base_source
        target_suffix = ""
      else
        source = File.join(dir_name, "#{base_name_without_ext}@#{scale}#{ext}")
        target_suffix = "@#{scale}"
      end

      # Determine target filename
      target = File.join(project.export_path, "#{target_base_name}#{target_suffix}#{ext}")

      if File.exist?(source)
        FileUtils.cp(source, target)
        export_count += 1
      end
    end
  end

  json success: true, count: export_count, path: project.export_path
end
