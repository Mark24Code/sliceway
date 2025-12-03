require 'psd'
require 'rmagick'
require 'fileutils'
require 'securerandom'
require_relative 'models'

# 性能监控类
class PerformanceMonitor
  def self.memory_usage
    `ps -o rss= -p #{Process.pid}`.to_i / 1024
  rescue
    0 # 如果无法获取内存使用情况，返回0
  end
end

class PsdProcessor
  LAYER_TYPE_MAP = {
    'slice' => '切片',
    'layer' => '图层',
    'group' => '组',
    'text' => '文本'
  }.freeze

  def initialize(project_id)
    @project = Project.find(project_id)
    public_path = ENV['PUBLIC_PATH'] || 'public'
    @output_dir = File.join(public_path, "processed", @project.id.to_s)
    FileUtils.mkdir_p(@output_dir)
    @processed_count = 0 # 用于跟踪处理的总数量
  end

  # 定期打印内存使用情况
  def log_memory_periodically
    @processed_count += 1
    if @processed_count % 20 == 0
      memory = PerformanceMonitor.memory_usage
      puts "-" * 60
      puts "[内存监控] 已处理 #{@processed_count} 个项目, 当前内存: #{memory} MB"
      puts "-" * 60
    end
  end

  def call
    @project.update(status: 'processing')

    # 记录初始内存
    initial_memory = PerformanceMonitor.memory_usage
    puts "✓ [开始处理] PSD文件, 初始内存: #{initial_memory} MB"

    begin
      PSD.open(@project.psd_path) do |psd|
        # 提取并保存文档尺寸
        save_document_dimensions(psd)

        # 1. 导出完整预览
        export_full_preview(psd)

        # 2. 导出切片
        export_slices(psd)

        # 3. 处理树结构（组、图层、文本）
        process_node(psd.tree)
      end

      final_memory = PerformanceMonitor.memory_usage
      puts "✓ [完成处理] 最终内存: #{final_memory} MB, 内存增长: #{final_memory - initial_memory} MB"

      @project.update(status: 'ready')
    rescue => e
      puts "✗ [处理失败] #{e.message}"
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

    puts "✓ [保存尺寸] #{width} × #{height} px"
  end

  def export_full_preview(psd)
    path = File.join(@output_dir, "full_preview.png")

    # Check if the source file is a PSB
    if File.extname(@project.psd_path).downcase == '.psb'
      image = nil
      begin
        # Use RMagick to convert PSB to PNG
        image = Magick::Image.read(@project.psd_path + "[0]").first
        image.write(path)
      rescue => e
        puts "⚠ [预览生成] RMagick 生成预览失败: #{e.message}"
        psd_image = psd.image
        psd_image.save_as_png(path)
        psd_image = nil
      ensure
        # 显式销毁 RMagick 图像对象以释放内存
        if image
          image.destroy!
          image = nil
        end
      end
    else
      # Use existing logic for PSD
      psd_image = psd.image
      psd_image.save_as_png(path)
      psd_image = nil
    end
  end

  def export_slices(psd)
    slices = psd.slices.to_a

    # 如果没有切片，直接返回
    return if slices.empty?

    # 根据切片数量决定是否使用并行处理
    if slices.length > 3
      export_slices_parallel(slices)
    else
      export_slices_sequential(slices)
    end
  end

  # 并行处理切片
  def export_slices_parallel(slices)
    # 分批处理以控制内存使用和并发度
    slices.each_slice(3) do |slice_batch|
      threads = slice_batch.map do |slice|
        Thread.new { process_slice(slice) }
      end

      # 等待当前批次的所有线程完成
      threads.each(&:join)
    end
  end

  # 顺序处理切片
  def export_slices_sequential(slices)
    slices.each do |slice|
      process_slice(slice)
    end
  end

  # 处理单个切片
  def process_slice(slice)
    # 跳过宽度或高度为0的切片
    if slice.width == 0 || slice.height == 0
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

      puts "✓ [导出切片] #{slice.name} (#{slice.width}×#{slice.height})"
      log_memory_periodically
    rescue => e
      puts "✗ [导出切片] #{slice.name} 失败: #{e.message}"
    ensure
      # 显式释放 PNG 对象
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
      puts "- [跳过节点] #{node.name}, 尺寸: #{node.width}×#{node.height}"
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

    puts "✓ [导出#{LAYER_TYPE_MAP[layer_type] || layer_type}] #{node.name} (#{node.width}×#{node.height})"
    log_memory_periodically

    # 如果是组，递归处理子节点
    if node.group?
      node.children.each do |child|
        process_node(child, record.id)
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
      puts "✗ [导出组(含文本)] #{node.name} 失败: #{e.message}"
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
      puts "✗ [导出组(无文本)] #{node.name} 失败: #{e.message}"
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
      puts "✗ [导出文本] #{node.name} 失败: #{e.message}"
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
      puts "✗ [导出图层] #{node.name} 失败: #{e.message}"
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
      puts "⚠ [图像验证] #{base_filename} 的PNG数据无效"
      return nil
    end

    scales = @project.export_scales || ['1x']
    saved_base_path = nil

    base_name = File.basename(base_filename, ".*")
    ext = File.extname(base_filename)
    original_path = nil

    begin
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
          end
        rescue => e
          puts "✗ [图像缩放] #{base_filename} 在比例 #{scale} 时失败: #{e.message}"
          # 继续处理其他比例
        end
      end
    ensure
      # 确保所有PNG对象都被释放
      png = nil
    end

    saved_base_path
  end
end
