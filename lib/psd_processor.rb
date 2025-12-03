require 'psd'
require 'rmagick'
require 'fileutils'
require 'securerandom'
require_relative 'models'

# 性能监控类
class PerformanceMonitor
  def self.measure(operation_name)
    start_time = Time.now
    start_memory = memory_usage

    result = yield

    end_time = Time.now
    end_memory = memory_usage

    duration = end_time - start_time
    memory_delta = end_memory - start_memory

    puts "性能监控: #{operation_name} - 耗时: #{duration.round(2)}秒, 内存变化: #{memory_delta} MB"

    { time: duration, memory_delta: memory_delta, result: result }
  end

  def self.memory_usage
    `ps -o rss= -p #{Process.pid}`.to_i / 1024
  rescue
    0 # 如果无法获取内存使用情况，返回0
  end
end

class PsdProcessor
  def initialize(project_id)
    @project = Project.find(project_id)
    public_path = ENV['PUBLIC_PATH'] || 'public'
    @output_dir = File.join(public_path, "processed", @project.id.to_s)
    FileUtils.mkdir_p(@output_dir)
    @processed_children = 0 # 用于跟踪处理的子节点数量
  end

  # 强制垃圾回收并记录内存使用情况
  def force_gc_after_large_operation(operation_name)
    before_memory = PerformanceMonitor.memory_usage
    puts "#{operation_name} 前内存: #{before_memory} MB"

    # 强制完整的垃圾回收
    3.times do
      GC.start(full_mark: true, immediate_sweep: true)
    end

    after_memory = PerformanceMonitor.memory_usage
    freed_memory = before_memory - after_memory
    puts "#{operation_name} 后内存: #{after_memory} MB (释放: #{freed_memory} MB)"
  end

  def call
    @project.update(status: 'processing')

    # 记录初始内存
    initial_memory = PerformanceMonitor.memory_usage
    puts "="*60
    puts "开始处理PSD: #{@project.psd_path}"
    puts "初始内存使用: #{initial_memory} MB"
    puts "="*60

    begin
      PerformanceMonitor.measure("完整PSD处理") do
        PSD.open(@project.psd_path) do |psd|
          # 提取并保存文档尺寸
          save_document_dimensions(psd)

          # 1. 导出完整预览
          export_full_preview(psd)
          force_gc_after_large_operation("完整预览导出")

          # 2. 导出切片
          export_slices(psd)
          force_gc_after_large_operation("切片导出")

          # 3. 处理树结构（组、图层、文本）
          process_node(psd.tree)
          force_gc_after_large_operation("树结构处理")
        end
      end

      final_memory = PerformanceMonitor.memory_usage
      memory_increase = final_memory - initial_memory
      puts "="*60
      puts "PSD处理完成"
      puts "最终内存使用: #{final_memory} MB"
      puts "内存增长: #{memory_increase} MB"
      puts "="*60

      @project.update(status: 'ready')
    rescue => e
      puts "处理PSD时出错: #{e.message}"
      puts e.backtrace
      @project.update(status: 'error')
    end
  end

  private

  def save_document_dimensions(psd)
    # Extract document dimensions from PSD
    width = psd.width
    height = psd.height

    # Save dimensions to project
    @project.update(width: width, height: height)

    puts "Document dimensions saved: #{width} x #{height} px"
  end

  def export_full_preview(psd)
    path = File.join(@output_dir, "full_preview.png")

    # Check if the source file is a PSB
    if File.extname(@project.psd_path).downcase == '.psb'
      puts "Detected PSB file, using RMagick for preview generation..."
      image = nil
      begin
        # Use RMagick to convert PSB to PNG
        # [0] selects the flattened layer (usually the first image in the sequence for PSD/PSB)
        image = Magick::Image.read(@project.psd_path + "[0]").first
        image.write(path)
      rescue => e
        puts "Warning: RMagick failed to generate preview: #{e.message}"
        puts "Falling back to ruby-psd (which may fail for large PSB)"
        psd_image = psd.image
        psd_image.save_as_png(path)
        psd_image = nil
      ensure
        # 显式销毁 RMagick 图像对象以释放内存
        if image
          image.destroy!
          image = nil
        end
        GC.start(full_mark: true, immediate_sweep: true)
      end
    else
      # Use existing logic for PSD
      psd_image = psd.image
      psd_image.save_as_png(path)
      psd_image = nil
      GC.start(full_mark: true, immediate_sweep: true)
    end
  end

  def export_slices(psd)
    slices = psd.slices.to_a

    # 如果没有切片，直接返回
    return if slices.empty?

    puts "开始处理 #{slices.length} 个切片"

    # 根据切片数量决定是否使用并行处理
    if slices.length > 3
      export_slices_parallel(slices)
    else
      export_slices_sequential(slices)
    end
  end

  # 并行处理切片
  def export_slices_parallel(slices)
    puts "使用并行处理切片"

    # 分批处理以控制内存使用和并发度
    slices.each_slice(3) do |slice_batch|
      threads = slice_batch.map do |slice|
        Thread.new { process_slice(slice) }
      end

      # 等待当前批次的所有线程完成
      threads.each(&:join)

      # 批次处理完成后强制垃圾回收
      GC.start(full_mark: true, immediate_sweep: true)
      puts "切片批次完成: 当前内存: #{PerformanceMonitor.memory_usage} MB"
    end
  end

  # 顺序处理切片
  def export_slices_sequential(slices)
    puts "使用顺序处理切片"
    slices.each do |slice|
      process_slice(slice)
    end
  end

  # 处理单个切片
  def process_slice(slice)
    # 跳过宽度或高度为0的切片
    if slice.width == 0 || slice.height == 0
      puts "跳过切片 #{slice.name}，尺寸为 #{slice.width}x#{slice.height}"
      return
    end

    filename = "slice_#{slice.id}_#{SecureRandom.hex(4)}.png"
    png = nil

    begin
      png = slice.to_png
      return unless png

      saved_path = save_scaled_images(png, filename)

      Layer.create!(
        project_id: @project.id,
        resource_id: slice.id.to_s,
        name: slice.name,
        layer_type: 'slice',
        x: slice.left,
        y: slice.top,
        width: slice.width,
        height: slice.height,
        image_path: saved_path,
        metadata: { scales: @project.export_scales || ['1x'] }
      )
    rescue => e
      puts "导出切片 #{slice.name} 失败: #{e.message}"
      puts e.backtrace if e.message.include?('nil')
    ensure
      # 显式释放 PNG 对象
      png = nil
      if @processed_children % 5 == 0  # 每5个切片强制GC
        GC.start(full_mark: true, immediate_sweep: true)
        puts "切片处理: 已处理 #{@processed_children} 个, 当前内存: #{PerformanceMonitor.memory_usage} MB"
      end
    end
  end

  def process_node(node, parent_id = nil)
    # 跳过根节点本身，但处理其子节点
    if node.root?
      node.children.each { |child| process_node(child, parent_id) }
      return
    end

    # 跳过宽度或高度为0的节点
    if node.width == 0 || node.height == 0
      puts "跳过节点 #{node.name}，尺寸为 #{node.width}x#{node.height}"
      return
    end

    layer_type = determine_type(node)

    # 准备记录属性
    attrs = {
      project_id: @project.id,
      name: node.name,
      layer_type: layer_type,
      x: node.left,
      y: node.top,
      width: node.width,
      height: node.height,
      parent_id: parent_id,
      metadata: { scales: @project.export_scales || ['1x'] }
    }

    # 处理特定类型
    if layer_type == 'group'
      handle_group(node, attrs)
    elsif layer_type == 'text'
      handle_text(node, attrs)
    else # layer
      handle_layer(node, attrs)
    end

    # 保存记录
    record = Layer.create!(attrs)

    # 如果是组，递归处理子节点
    if node.group?
      node.children.each do |child|
        process_node(child, record.id)
        # 每处理10个子节点后强制垃圾回收
        @processed_children += 1
        if @processed_children % 10 == 0
          GC.start(full_mark: true, immediate_sweep: true)
          puts "节点处理: 已处理 #{@processed_children} 个子节点, 当前内存: #{PerformanceMonitor.memory_usage} MB"
        end
      end
    end
  end

  def handle_group(node, attrs)
    # Export with text
    filename_with = "group_#{node.id}_with_text_#{SecureRandom.hex(4)}.png"
    png = nil

    begin
      png = node.to_png
      saved_path = save_scaled_images(png, filename_with)
      attrs[:image_path] = saved_path
    rescue => e
      puts "Failed to export group #{node.name} with text: #{e.message}"
    ensure
      png = nil  # 释放 PNG 对象
    end

    # Export without text (using logic from export_groups.rb)
    filename_without = "group_#{node.id}_no_text_#{SecureRandom.hex(4)}.png"
    png_without = nil

    begin
      png_without = render_group_without_text(node)
      saved_path = save_scaled_images(png_without, filename_without)
      attrs[:metadata][:image_path_no_text] = saved_path
    rescue => e
      puts "Failed to export group #{node.name} without text: #{e.message}"
    ensure
      png_without = nil  # 释放 PNG 对象
    end
  end

  def handle_text(node, attrs)
    if node.text
      attrs[:content] = node.text[:value]
      attrs[:metadata][:font] = node.text[:font]
    end
    # Text layers also have an image representation usually
    filename = "text_#{node.id}_#{SecureRandom.hex(4)}.png"
    png = nil

    begin
      png = node.to_png
      saved_path = save_scaled_images(png, filename)
      attrs[:image_path] = saved_path
    rescue => e
      puts "Failed to export text layer #{node.name}: #{e.message}"
    ensure
      png = nil  # 释放 PNG 对象
    end
  end

  def handle_layer(node, attrs)
    filename = "layer_#{node.id}_#{SecureRandom.hex(4)}.png"
    png = nil

    begin
      png = node.to_png
      saved_path = save_scaled_images(png, filename)
      attrs[:image_path] = saved_path
    rescue => e
      puts "Failed to export layer #{node.name}: #{e.message}"
    ensure
      png = nil  # 释放 PNG 对象
    end
  end

  def determine_type(node)
    return 'group' if node.group?
    return 'text' if text_layer?(node)
    'layer'
  end

  def text_layer?(node)
    node.respond_to?(:layer) &&
    node.layer.respond_to?(:info) &&
    node.layer.info &&
    !node.layer.info[:type].nil?
  end

  def render_group_without_text(group)
    visibility_states = {}
    renderer = nil
    png = nil

    begin
      # 保存并隐藏所有文本图层
      group.descendants.each do |node|
        if text_layer?(node)
          visibility_states[node] = node.force_visible
          node.force_visible = false
        end
      end

      # 渲染组
      renderer = PSD::Renderer.new(group, render_hidden: true)
      renderer.render!
      png = renderer.to_png
    ensure
      # 恢复文本图层可见性
      visibility_states.each do |node, state|
        node.force_visible = state
      end

      # 清理临时变量
      visibility_states.clear
      visibility_states = nil
      renderer = nil
    end

    png
  end

  def relative_path(filename)
    File.join("processed", @project.id.to_s, filename)
  end

  def save_scaled_images(png, base_filename)
    return nil unless png

    # 添加图像数据验证
    unless png.respond_to?(:save) && png.respond_to?(:width) && png.respond_to?(:height)
      puts "警告: #{base_filename} 的PNG数据无效"
      return nil
    end

    scales = @project.export_scales || ['1x']
    saved_base_path = nil

    base_name = File.basename(base_filename, ".*")
    ext = File.extname(base_filename)
    original_path = nil

    begin
      PerformanceMonitor.measure("图像缩放处理: #{base_filename}") do
        scales.each_with_index do |scale, index|
          begin
            if scale == '1x'
              path = File.join(@output_dir, base_filename)
              original_path = path
              png.save(path, :fast_rgba)
              saved_base_path = relative_path(base_filename)

              # 如果有多个缩放比例,且不是最后一个,释放原始PNG以节省内存
              if scales.length > 1 && index < scales.length - 1
                png = nil  # 释放原始图像对象
                GC.start(full_mark: true, immediate_sweep: true)  # 立即触发完整垃圾回收
              end
            else
              # 如果需要缩放但原始PNG已释放,从磁盘重新加载
              if png.nil? && original_path
                png = ChunkyPNG::Image.from_file(original_path)
              end

              next unless png  # 如果无法加载PNG,跳过此比例

              # 计算新尺寸
              factor = scale.to_i
              new_width = png.width * factor
              new_height = png.height * factor

              # 使用ChunkyPNG调整大小
              resized_png = png.resample_nearest_neighbor(new_width, new_height)

              filename = "#{base_name}@#{scale}#{ext}"
              path = File.join(@output_dir, filename)
              resized_png.save(path, :fast_rgba)

              # 立即释放缩放后的图像对象
              resized_png = nil

              # 如果未请求1x,使用第一个生成的缩放比例作为"基本"路径
              saved_base_path ||= relative_path(filename)

              # 每处理一个缩放比例后触发完整垃圾回收
              GC.start(full_mark: true, immediate_sweep: true)
            end
          rescue => e
            puts "保存缩放图像 #{base_filename} 在比例 #{scale} 时出错: #{e.message}"
            # 继续处理其他比例
          end
        end
      end
    ensure
      # 确保所有PNG对象都被释放
      png = nil
      GC.start(full_mark: true, immediate_sweep: true)
    end

    saved_base_path
  end
end
