require 'sinatra'
require 'sinatra/json'
require 'rack/cors'
require 'fileutils'
require_relative 'lib/database'
require_relative 'lib/models'
require_relative 'lib/psd_processor'

set :public_folder, 'public'
set :bind, '0.0.0.0'
set :port, 4567

use Rack::Cors do
  allow do
    origins '*'
    resource '*', headers: :any, methods: [:get, :post, :delete, :put, :options], expose: ['location', 'link']
  end
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
    # Save file to uploads
    upload_dir = File.join("uploads")
    FileUtils.mkdir_p(upload_dir)
    target_path = File.join(upload_dir, "#{Time.now.to_i}_#{filename}")
    File.open(target_path, 'wb') do |f|
      f.write(params[:file][:tempfile].read)
    end
    
    project = Project.create!(
      name: params[:name] || filename,
      psd_path: File.absolute_path(target_path), # Store absolute path
      export_path: params[:export_path] || File.join(Dir.pwd, "exports", "#{Time.now.to_i}"),
      status: 'pending'
    )
    
    # Trigger processing in a thread
    task_thread = Thread.new do
      begin
        PsdProcessor.new(project.id).call
      ensure
        # 任务完成后从运行任务列表中移除
        $running_tasks.delete(project.id)
      end
    end

    # 保存任务线程到全局变量
    $running_tasks[project.id] = task_thread
    
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

  # 在后台线程中处理PSD文件
  task_thread = Thread.new do
    begin
      PsdProcessor.new(project.id).call
    rescue => e
      project.update(status: 'error')
      puts "PSD处理失败: #{e.message}"
    ensure
      # 任务完成后从运行任务列表中移除
      $running_tasks.delete(project.id)
    end
  end

  # 保存任务线程到全局变量
  $running_tasks[project.id] = task_thread

  json success: true
end

# 全局变量来跟踪正在运行的任务
$running_tasks = {}

delete '/api/projects/:id' do
  project = Project.find(params[:id])

  # 如果项目正在处理中，中止任务
  if project.status == 'processing'
    # 中止对应的处理任务
    if $running_tasks[project.id]
      Thread.kill($running_tasks[project.id])
      $running_tasks.delete(project.id)
      puts "中止了项目 #{project.id} 的处理任务"
    end
  end

  # Clean up files
  begin
    # Clean up uploaded PSD file
    if project.psd_path && File.exist?(project.psd_path)
      FileUtils.rm_rf(project.psd_path)
    end

    # Clean up export directory
    if project.export_path && Dir.exist?(project.export_path)
      FileUtils.rm_rf(project.export_path)
    end

    # Clean up exported images in public directory
    project.layers.each do |layer|
      if layer.image_path && File.exist?(File.join('public', layer.image_path))
        FileUtils.rm_rf(File.join('public', layer.image_path))
      end
    end

    # Clean up processed images directory
    processed_dir = File.join('public', 'processed', project.id.to_s)
    if Dir.exist?(processed_dir)
      FileUtils.rm_rf(processed_dir)
    end
  rescue => e
    puts "Warning: Failed to clean up some files: #{e.message}"
  end

  project.destroy
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
  
  layers = project.layers.where(id: layer_ids)
  export_count = 0
  
  FileUtils.mkdir_p(project.export_path)
  
  layers.each do |layer|
    next unless layer.image_path
    source = File.join("public", layer.image_path)
    # Ensure unique filename in export
    target = File.join(project.export_path, "#{layer.name}_#{layer.id}.png")
    
    if File.exist?(source)
      FileUtils.cp(source, target)
      export_count += 1
    end
  end
  
  json success: true, count: export_count, path: project.export_path
end
