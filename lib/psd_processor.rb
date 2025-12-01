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

# 内存监控和限制类
class MemoryMonitor
  # 获取系统总内存（MB）
  def self.total_memory_mb
    if RUBY_PLATFORM =~ /linux/
      # Linux: 从/proc/meminfo读取
      meminfo = File.read('/proc/meminfo') rescue nil
      if meminfo && meminfo =~ /MemTotal:\s+(\d+) kB/
        return $1.to_i / 1024
      end
    elsif RUBY_PLATFORM =~ /darwin/
      # macOS: 使用sysctl
      result = `sysctl hw.memsize 2>/dev/null`.chomp
      if result =~ /hw\.memsize: (\d+)/
        return $1.to_i / (1024 * 1024)
      end
    end
    # 默认假设8GB
    8192
  end

  # 获取当前进程内存使用（MB）
  def self.current_usage
    PerformanceMonitor.memory_usage
  end

  # 检查内存是否超过限制
  # @param soft_limit_ratio [Float] 软限制比例，默认0.7（70%）
  # @param hard_limit_ratio [Float] 硬限制比例，默认0.8（80%）
  # @return [Symbol] :ok, :soft_limit_exceeded, :hard_limit_exceeded
  def self.check_memory(soft_limit_ratio = 0.7, hard_limit_ratio = 0.8)
    total_mem = total_memory_mb
    current_mem = current_usage
    soft_limit = total_mem * soft_limit_ratio
    hard_limit = total_mem * hard_limit_ratio

    puts "内存监控: 当前 #{current_mem} MB, 软限制 #{soft_limit.round} MB, 硬限制 #{hard_limit.round} MB, 总内存 #{total_mem} MB"

    if current_mem > hard_limit
      :hard_limit_exceeded
    elsif current_mem > soft_limit
      :soft_limit_exceeded
    else
      :ok
    end
  end

  # 等待内存释放（阻塞直到内存低于限制或超时）
  # @param target_ratio [Float] 目标内存比例
  # @param timeout_seconds [Integer] 超时时间（秒）
  # @return [Boolean] 是否成功将内存降低到目标以下
  def self.wait_for_memory_release(target_ratio = 0.6, timeout_seconds = 60)
    start_time = Time.now
    target_mem = total_memory_mb * target_ratio

    while Time.now - start_time < timeout_seconds
      current_mem = current_usage
      if current_mem < target_mem
        puts "内存监控: 内存已降低到 #{current_mem} MB，低于目标 #{target_mem.round} MB"
        return true
      end

      puts "内存监控: 等待内存释放... 当前 #{current_mem} MB，目标 #{target_mem.round} MB"
      GC.start
      sleep 2
    end

    puts "内存监控: 等待内存释放超时"
    false
  end
end

class PsdProcessor
  def initialize(project_id)
    @project = Project.find(project_id)
    public_path = ENV['PUBLIC_PATH'] || 'public'
    @output_dir = File.join(public_path, "processed", @project.id.to_s)
    FileUtils.mkdir_p(@output_dir)
    @processed_children = 0 # 用于跟踪处理的子节点数量

    # 默认处理策略（小文件模式）
    @parallel_enabled = true
    @batch_size = 3
    @use_disk_cache = false

    # 资源跟踪
    @resources_to_clean = {}
    # 实时监控线程
    @monitor_thread = nil

    # 根据文件大小优化处理策略
    optimize_for_large_files
  end

  # 强制垃圾回收并记录内存使用情况
  def force_gc_after_large_operation(operation_name)
    puts "在 #{operation_name} 后强制垃圾回收"
    GC.start
    memory_usage = PerformanceMonitor.memory_usage
    puts "#{operation_name} 后内存使用: #{memory_usage} MB"
  end

  def call
    @project.update(status: 'processing')

    # 启动实时内存监控
    start_realtime_monitoring

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

      @project.update(status: 'ready')
    rescue => e
      puts "处理PSD时出错: #{e.message}"
      puts e.backtrace
      @project.update(status: 'error')
      # 错误发生时记录日志
      puts "错误发生，将清理资源..."
    ensure
      # 停止实时内存监控
      stop_realtime_monitoring
      # 确保清理所有残留资源
      cleanup_resources
    end
  end

  # 根据文件大小优化处理策略
  def optimize_for_large_files
    return unless @project.psd_path && File.exist?(@project.psd_path)

    file_size = File.size(@project.psd_path)
    file_size_mb = file_size / (1024 * 1024).to_f

    puts "文件大小: #{file_size_mb.round(2)} MB"

    # 设置处理策略
    if file_size_mb > 500
      # 大文件 (>500MB): 禁用并行处理，减小批次大小，使用磁盘缓存
      @parallel_enabled = false
      @batch_size = 1
      @use_disk_cache = true
      puts "使用大文件优化策略: 禁用并行处理，批次大小=1，启用磁盘缓存"
    elsif file_size_mb > 100
      # 中等文件 (100-500MB): 平衡模式
      @parallel_enabled = true
      @batch_size = 2
      @use_disk_cache = false
      puts "使用中等文件优化策略: 启用并行处理，批次大小=2，禁用磁盘缓存"
    else
      # 小文件 (<100MB): 标准模式
      @parallel_enabled = true
      @batch_size = 3
      @use_disk_cache = false
      puts "使用小文件优化策略: 启用并行处理，批次大小=3，禁用磁盘缓存"
    end
  end

  # 注册需要清理的资源
  def register_resource(type, object, id = nil)
    id ||= object.object_id
    @resources_to_clean[type] ||= {}
    @resources_to_clean[type][id] = object
    puts "注册 #{type} 资源，ID: #{id}" if ENV['DEBUG_RESOURCES']
  end

  # 取消注册资源（当资源已通过其他方式清理时）
  def unregister_resource(type, id)
    if @resources_to_clean[type]&.delete(id)
      puts "取消注册 #{type} 资源，ID: #{id}" if ENV['DEBUG_RESOURCES']
    end
  end

  # 清理所有已注册的资源
  def cleanup_resources
    puts "清理 #{@resources_to_clean.values.sum { |h| h.size }} 个资源" if @resources_to_clean.any?

    # 清理RMagick图像
    if @resources_to_clean[:rmagick]
      @resources_to_clean[:rmagick].each do |id, image|
        begin
          image&.destroy!
          puts "清理 RMagick 图像 #{id}" if ENV['DEBUG_RESOURCES']
        rescue => e
          puts "清理 RMagick 图像 #{id} 时出错: #{e.message}"
        end
      end
      @resources_to_clean.delete(:rmagick)
    end

    # 清理PSD渲染器
    if @resources_to_clean[:renderer]
      @resources_to_clean[:renderer].each do |id, renderer|
        renderer = nil # 只是解除引用，让GC处理
        puts "清理 PSD 渲染器 #{id}" if ENV['DEBUG_RESOURCES']
      end
      @resources_to_clean.delete(:renderer)
    end

    # 清理临时文件
    if @resources_to_clean[:temp_file]
      @resources_to_clean[:temp_file].each do |id, path|
        begin
          File.delete(path) if File.exist?(path)
          puts "清理临时文件 #{path}" if ENV['DEBUG_RESOURCES']
        rescue => e
          puts "清理临时文件 #{path} 时出错: #{e.message}"
        end
      end
      @resources_to_clean.delete(:temp_file)
    end

    # 清理PNG对象（解除引用）
    @resources_to_clean.each do |type, objects|
      objects.each { |id, obj| obj = nil }
    end
    @resources_to_clean.clear
  end

  # 启动实时内存监控
  def start_realtime_monitoring(interval_seconds = 5)
    return unless ENV['ENABLE_REAL_TIME_MONITOR']
    return if @monitor_thread&.alive?

    puts "启动实时内存监控，间隔 #{interval_seconds} 秒"
    @monitor_thread = Thread.new do
      begin
        while true
          mem = MemoryMonitor.current_usage
          total = MemoryMonitor.total_memory_mb
          puts "实时监控: 内存使用 #{mem} MB / #{total} MB (#{(mem.to_f / total * 100).round(1)}%)"
          sleep interval_seconds
        end
      rescue => e
        puts "实时监控线程出错: #{e.message}"
      end
    end
  end

  # 停止实时内存监控
  def stop_realtime_monitoring
    return unless @monitor_thread&.alive?

    puts "停止实时内存监控"
    @monitor_thread.kill
    @monitor_thread = nil
  end

  private

  # 检查内存限制并采取相应措施
  def check_and_handle_memory_limit
    case MemoryMonitor.check_memory
    when :hard_limit_exceeded
      puts "内存监控: 硬限制 exceeded，执行紧急清理"
      GC.start
      # 等待内存释放到软限制以下
      MemoryMonitor.wait_for_memory_release(0.6, 30)
    when :soft_limit_exceeded
      puts "内存监控: 软限制 exceeded，触发垃圾回收"
      GC.start
      # 短暂暂停
      sleep 1
    end
  end

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
        register_resource(:rmagick, image) if image
        image.write(path)
      rescue => e
        puts "Warning: RMagick failed to generate preview: #{e.message}"
        puts "Falling back to ruby-psd (which may fail for large PSB)"
        psd.image.save_as_png(path)
      ensure
        # 关键修复：显式释放RMagick对象
        if image
          image&.destroy!
          unregister_resource(:rmagick, image.object_id)
        end
      end
    else
      # Use existing logic for PSD
      psd.image.save_as_png(path)
    end
  end

  def export_slices(psd)
    slices = psd.slices.to_a

    # 如果没有切片，直接返回
    return if slices.empty?

    puts "开始处理 #{slices.length} 个切片"

    # 根据文件大小优化策略决定是否使用并行处理
    if @parallel_enabled && slices.length > @batch_size
      export_slices_parallel(slices)
    else
      export_slices_sequential(slices)
    end
  end

  # 并行处理切片
  def export_slices_parallel(slices)
    puts "使用并行处理切片，批次大小: #{@batch_size}"

    # 分批处理以控制内存使用和并发度
    slices.each_slice(@batch_size) do |slice_batch|
      # 检查内存限制，必要时暂停或清理
      check_and_handle_memory_limit

      threads = slice_batch.map do |slice|
        Thread.new { process_slice(slice) }
      end

      # 等待当前批次的所有线程完成
      threads.each(&:join)

      # 批次处理完成后强制垃圾回收
      force_gc_after_large_operation("切片批次处理")
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
      # 显式释放PNG对象
      png = nil
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
          force_gc_after_large_operation("处理#{@processed_children}个子节点")
        end
      end
    end
  end

  def handle_group(node, attrs)
    # Export with text
    filename_with = "group_#{node.id}_with_text_#{SecureRandom.hex(4)}.png"

    begin
      png = node.to_png
      saved_path = save_scaled_images(png, filename_with)
      attrs[:image_path] = saved_path
    rescue => e
      puts "Failed to export group #{node.name} with text: #{e.message}"
    ensure
      # 显式释放PNG对象
      png = nil
    end

    # Export without text (using logic from export_groups.rb)
    filename_without = "group_#{node.id}_no_text_#{SecureRandom.hex(4)}.png"

    begin
      png = render_group_without_text(node)
      saved_path = save_scaled_images(png, filename_without)
      attrs[:metadata][:image_path_no_text] = saved_path
    rescue => e
      puts "Failed to export group #{node.name} without text: #{e.message}"
    ensure
      # 显式释放PNG对象
      png = nil
    end
  end

  def handle_text(node, attrs)
    if node.text
      attrs[:content] = node.text[:value]
      attrs[:metadata][:font] = node.text[:font]
    end
    # Text layers also have an image representation usually
    filename = "text_#{node.id}_#{SecureRandom.hex(4)}.png"
    begin
      png = node.to_png
      saved_path = save_scaled_images(png, filename)
      attrs[:image_path] = saved_path
    rescue => e
      puts "Failed to export text layer #{node.name}: #{e.message}"
    ensure
      # 显式释放PNG对象
      png = nil
    end
  end

  def handle_layer(node, attrs)
    filename = "layer_#{node.id}_#{SecureRandom.hex(4)}.png"
    begin
      png = node.to_png
      saved_path = save_scaled_images(png, filename)
      attrs[:image_path] = saved_path
    rescue => e
      puts "Failed to export layer #{node.name}: #{e.message}"
    ensure
      # 显式释放PNG对象
      png = nil
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
      group.descendants.each do |node|
        if text_layer?(node)
          visibility_states[node] = node.force_visible
          node.force_visible = false
        end
      end

      renderer = PSD::Renderer.new(group, render_hidden: true)
      register_resource(:renderer, renderer) if renderer
      renderer.render!
      png = renderer.to_png
    ensure
      # 恢复可见性状态
      visibility_states.each do |node, state|
        node.force_visible = state
      end
      # 显式释放渲染器
      if renderer
        unregister_resource(:renderer, renderer.object_id)
        renderer = nil
      end
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
    resized_png = nil  # 显式声明变量

    base_name = File.basename(base_filename, ".*")
    ext = File.extname(base_filename)

    PerformanceMonitor.measure("图像缩放处理: #{base_filename}") do
      scales.each do |scale|
        begin
          if scale == '1x'
            path = File.join(@output_dir, base_filename)
            png.save(path, :fast_rgba)
            saved_base_path = relative_path(base_filename)

            # 如果有多个缩放比例，释放原始PNG以节省内存
            if scales.length > 1
              png = nil  # 释放原始图像对象
            end
          else
            # 如果需要缩放但原始PNG已释放，从磁盘重新加载
            if png.nil?
              original_path = File.join(@output_dir, base_filename)
              png = ChunkyPNG::Image.from_file(original_path)
            end

            # 计算新尺寸
            factor = scale.to_i
            new_width = png.width * factor
            new_height = png.height * factor

            # 使用ChunkyPNG调整大小
            # 注意: psd.to_png返回ChunkyPNG::Image
            resized_png = png.resample_nearest_neighbor(new_width, new_height)

            filename = "#{base_name}@#{scale}#{ext}"
            path = File.join(@output_dir, filename)
            resized_png.save(path, :fast_rgba)

            # 立即释放缩放后的图像对象
            resized_png = nil

            # 如果未请求1x，我们仍需要基本路径用于预览
            # 如果未设置，使用第一个生成的缩放比例作为"基本"路径
            saved_base_path ||= relative_path(filename)
          end
        rescue => e
          puts "保存缩放图像 #{base_filename} 在比例 #{scale} 时出错: #{e.message}"
          # 继续处理其他比例
        ensure
          # 确保释放临时对象
          resized_png = nil
        end
      end
    end

    saved_base_path
  ensure
    # 最终清理
    png = nil
    resized_png = nil
  end
end
