require 'chunky_png'
require_relative 'models'

class ThreadWorker
  def initialize(worker_id, memory_monitor)
    @worker_id = worker_id
    @memory_monitor = memory_monitor
    @busy = false
    @current_task = nil
  end

  def process(task)
    @busy = true
    @current_task = task

    begin
      # 检查内存使用情况
      if @memory_monitor.memory_usage_exceeded?
        puts "Worker #{@worker_id}: Memory usage exceeded, waiting..."
        sleep(1) while @memory_monitor.memory_usage_exceeded?
      end

      result = process_task(task)

      # 任务完成后立即释放资源
      @current_task = nil
      @busy = false

      # 强制垃圾回收
      GC.start

      result

    rescue => e
      puts "Worker #{@worker_id}: Task processing error: #{e.message}"
      @current_task = nil
      @busy = false
      { success: false, error: e.message }
    end
  end

  def busy?
    @busy
  end

  def ready?
    !@busy
  end

  private

  def process_task(task)
    case task[:type]
    when :slice
      process_slice(task)
    when :text
      process_text_layer(task)
    when :layer
      process_regular_layer(task)
    else
      { success: false, error: "Unknown task type: #{task[:type]}" }
    end
  end

  def process_slice(task)
    slice = task[:slice]
    project_id = task[:project_id]

    begin
      # 导出切片
      png = slice.to_png
      return { success: false, error: "Failed to export slice" } unless png

      # 保存切片
      filename = "slice_#{slice.id}_#{SecureRandom.hex(4)}.png"
      saved_path = save_scaled_images(png, filename, project_id)

      # 创建图层记录
      Layer.create!(
        project_id: project_id,
        resource_id: slice.id.to_s,
        name: slice.name,
        layer_type: 'slice',
        x: slice.left,
        y: slice.top,
        width: slice.width,
        height: slice.height,
        image_path: saved_path,
        metadata: { scales: get_export_scales(project_id) }
      )

      { success: true, type: :slice, name: slice.name }

    rescue => e
      { success: false, error: "Slice processing failed: #{e.message}" }
    end
  end

  def process_text_layer(task)
    node = task[:node]
    project_id = task[:project_id]
    parent_id = task[:parent_id]

    begin
      # 导出文本图层
      png = node.to_png
      return { success: false, error: "Failed to export text layer" } unless png

      # 保存文本图层
      filename = "text_#{node.id}_#{SecureRandom.hex(4)}.png"
      saved_path = save_scaled_images(png, filename, project_id)

      # 创建图层记录
      attrs = {
        project_id: project_id,
        name: node.name,
        layer_type: 'text',
        x: node.left,
        y: node.top,
        width: node.width,
        height: node.height,
        parent_id: parent_id,
        image_path: saved_path,
        metadata: { scales: get_export_scales(project_id) }
      }

      # 添加文本内容
      if node.text
        attrs[:content] = node.text[:value]
        attrs[:metadata][:font] = node.text[:font]
      end

      Layer.create!(attrs)

      { success: true, type: :text, name: node.name }

    rescue => e
      { success: false, error: "Text layer processing failed: #{e.message}" }
    end
  end

  def process_regular_layer(task)
    node = task[:node]
    project_id = task[:project_id]
    parent_id = task[:parent_id]

    begin
      # 导出普通图层
      png = node.to_png
      return { success: false, error: "Failed to export layer" } unless png

      # 保存图层
      filename = "layer_#{node.id}_#{SecureRandom.hex(4)}.png"
      saved_path = save_scaled_images(png, filename, project_id)

      # 创建图层记录
      Layer.create!(
        project_id: project_id,
        name: node.name,
        layer_type: 'layer',
        x: node.left,
        y: node.top,
        width: node.width,
        height: node.height,
        parent_id: parent_id,
        image_path: saved_path,
        metadata: {
          scales: get_export_scales(project_id),
          has_text: task[:has_text]
        }
      )

      { success: true, type: :layer, name: node.name, has_text: task[:has_text] }

    rescue => e
      { success: false, error: "Layer processing failed: #{e.message}" }
    end
  end

  def save_scaled_images(png, base_filename, project_id)
    return nil unless png

    project = Project.find(project_id)
    output_dir = File.join("public", "processed", project_id.to_s)
    FileUtils.mkdir_p(output_dir)

    scales = project.export_scales || ['1x']
    saved_base_path = nil

    base_name = File.basename(base_filename, ".*")
    ext = File.extname(base_filename)

    scales.each do |scale|
      begin
        if scale == '1x'
          path = File.join(output_dir, base_filename)
          png.save(path, :fast_rgba)
          saved_base_path = File.join("processed", project_id.to_s, base_filename)
        else
          # 计算新尺寸
          factor = scale.to_i
          new_width = png.width * factor
          new_height = png.height * factor

          # 调整大小
          resized_png = png.resample_nearest_neighbor(new_width, new_height)

          filename = "#{base_name}@#{scale}#{ext}"
          path = File.join(output_dir, filename)
          resized_png.save(path, :fast_rgba)

          # 如果没有设置基础路径，使用第一个生成的缩放版本
          saved_base_path ||= File.join("processed", project_id.to_s, filename)
        end
      rescue => e
        puts "Error saving scaled image #{base_filename} at scale #{scale}: #{e.message}"
      end
    end

    saved_base_path
  end

  def get_export_scales(project_id)
    project = Project.find(project_id)
    project.export_scales || ['1x']
  end
end