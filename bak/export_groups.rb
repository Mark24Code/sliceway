#!/usr/bin/env ruby

require_relative 'psd.rb/lib/psd'
require 'json'
require 'digest'
require_relative 'progress_bar'
require_relative 'export_tracker'

class PSDGroupsExporter
  def initialize(psd_file_path, output_base_dir = 'output')
    @psd_file_path = psd_file_path
    @output_base_dir = output_base_dir
    @tracker = ExportTracker.new

    # 创建基础输出目录
    Dir.mkdir(@output_base_dir) unless Dir.exist?(@output_base_dir)
  end

  def export_groups
    puts "正在解析PSD文件: #{@psd_file_path}"

    PSD.open(@psd_file_path) do |psd|
      # puts "PSD文件信息:"
      # puts "  宽度: #{psd.header.width}"
      # puts "  高度: #{psd.header.height}"
      # puts "  颜色模式: #{psd.header.mode_name}"
      # puts "  通道数: #{psd.header.channels}"

      # 获取所有文件夹/组
      groups = psd.tree.descendant_groups.select { |group| group.respond_to?(:children) }
      puts "\n找到 #{groups.size} 个文件夹/组"

      if groups.empty?
        puts "警告: 该PSD文件中没有找到文件夹/组"
        return
      end

      # 为本次导出创建时间戳目录
      timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
      @export_dir = File.join(@output_base_dir, "groups_#{timestamp}")
      Dir.mkdir(@export_dir)

      # puts "\n导出目录: #{@export_dir}"

      # 创建子目录结构
      @images_dir = File.join(@export_dir, 'images')
      @metadata_dir = File.join(@export_dir, 'metadata')
      Dir.mkdir(@images_dir)
      Dir.mkdir(@metadata_dir)

      # 创建进度条
      progress = ProgressBar.new(groups.size, prefix: "导出文件夹/组", width: 40)

      # 导出每个文件夹/组
      groups.each_with_index do |group, index|
        export_group_with_text_versions(group, index + 1, psd)
        progress.increment(1)
      end

      progress.finish("文件夹/组导出完成")

      # 导出总体信息
      export_overall_metadata(psd, groups)

      puts "\n文件夹/组导出完成!"
      puts "  图片目录: #{@images_dir}"
      puts "  元数据目录: #{@metadata_dir}"
      puts "  总体信息: #{File.join(@export_dir, 'overall_info.json')}"
    end
  rescue => e
    puts "错误: #{e.message}"
    puts e.backtrace.join("\n") if ENV['DEBUG']
  end

  private

  def export_group_with_text_versions(group, index, psd)
    # puts "\n导出文件夹/组 #{index}:"
    # puts "  名称: #{group.name || '未命名'}"
    # puts "  位置: (#{group.left}, #{group.top})"
    # puts "  尺寸: #{group.width} x #{group.height}"
    # puts "  可见性: #{group.visible? ? '可见' : '隐藏'}"

    # 生成基础文件名
    base_filename = @tracker.generate_filename(group, :group)

    # 为每个组创建子目录
    group_dir = File.join(@images_dir, base_filename)
    Dir.mkdir(group_dir)

    # 创建两个版本子目录
    with_text_dir = File.join(group_dir, 'with_text')
    without_text_dir = File.join(group_dir, 'without_text')
    Dir.mkdir(with_text_dir)
    Dir.mkdir(without_text_dir)

    # 导出包含文字图层的版本
    # puts "  导出包含文字图层的版本..."
    export_group_version(group, with_text_dir, base_filename, true, index, psd)

    # 导出不包含文字图层的版本
    # puts "  导出不包含文字图层的版本..."
    export_group_version(group, without_text_dir, base_filename, false, index, psd)

    # 生成并导出元数据
    export_group_metadata(group, index, psd, base_filename)
  end

  def export_group_version(group, output_dir, base_filename, include_text, index, psd)
    version_suffix = include_text ? "with_text" : "without_text"
    image_filename = "#{base_filename}_#{version_suffix}.png"
    image_path = File.join(output_dir, image_filename)

    begin
      # 控制文字图层可见性
      if include_text
        # 包含文字图层 - 正常渲染
        png = group.to_png
      else
        # 不包含文字图层 - 创建自定义渲染器排除文字图层
        png = render_group_without_text(group)
      end

      png.save(image_path, :fast_rgba)
      # puts "    图片已保存: #{image_filename}"
    rescue => e
      puts "    图片导出失败: #{e.message}"
    end
  end

  def render_group_without_text(group)
    # 临时隐藏所有文字图层
    visibility_states = {}

    # 遍历组内所有图层，隐藏文字图层
    group.descendants.each do |node|
      if text_layer?(node)
        # 保存原始可见性状态
        visibility_states[node] = node.force_visible
        # 强制隐藏文字图层
        node.force_visible = false
      end
    end

    begin
      # 创建自定义渲染器，强制渲染所有图层（包括隐藏的）
      # 但文字图层已经被我们强制隐藏了
      renderer = PSD::Renderer.new(group, render_hidden: true)
      renderer.render!
      png = renderer.to_png
    ensure
      # 恢复原始可见性状态
      visibility_states.each do |node, state|
        node.force_visible = state
      end
    end

    png
  end

  def export_group_metadata(group, index, psd, base_filename)
    metadata_filename = "#{base_filename}.json"
    metadata_path = File.join(@metadata_dir, metadata_filename)

    begin
      metadata = generate_group_metadata(group, index, psd, base_filename)
      File.write(metadata_path, JSON.pretty_generate(metadata))
      # puts "  元数据已保存: #{metadata_filename}"
    rescue => e
      puts "  元数据导出失败: #{e.message}"
    end
  end

  def text_layer?(node)
    # 检查是否为文字图层
    node.respond_to?(:layer) &&
    node.layer.respond_to?(:info) &&
    node.layer.info &&
    !node.layer.info[:type].nil?
  end

  def generate_group_metadata(group, index, psd, base_filename)
    # 检查是否为真正的组（有子元素）
    is_real_group = group.respond_to?(:children) && group.respond_to?(:children_layers)

    metadata = {
      group_info: {
        id: group.id,
        name: group.name,
        index: index,
        path: group.path,
        depth: group.depth,
        type: is_real_group ? 'group' : 'layer'
      },

      visibility_and_appearance: {
        visible: group.visible?,
        opacity: group.opacity,
        blending_mode: group.blending_mode
      },

      geometry: {
        bounds: {
          left: group.left,
          top: group.top,
          right: group.right,
          bottom: group.bottom
        },
        dimensions: {
          width: group.width,
          height: group.height
        },
        position: {
          x: group.left,
          y: group.top
        }
      },

      structure: is_real_group ? {
        has_children: group.has_children?,
        children_count: group.children.size,
        layer_children_count: group.children_layers.size,
        group_children_count: group.children_groups.size,
        parent_path: group.parent ? group.parent.path : '根节点'
      } : {
        has_children: false,
        children_count: 0,
        layer_children_count: 0,
        group_children_count: 0,
        parent_path: group.parent ? group.parent.path : '根节点'
      },

      text_layers_info: {
        total_text_layers: count_text_layers(group),
        text_layers: extract_text_layers_info(group)
      },

      file_info: {
        base_filename: base_filename,
        image_versions: {
          with_text: "#{base_filename}/with_text/#{base_filename}_with_text.png",
          without_text: "#{base_filename}/without_text/#{base_filename}_without_text.png"
        },
        metadata_filename: "#{base_filename}.json",
        export_timestamp: Time.now.iso8601
      },

      # 子图层信息摘要（仅对真正的组有效）
      children_summary: is_real_group ? {
        layers: group.children_layers.map do |layer|
          {
            id: layer.id,
            name: layer.name,
            visible: layer.visible?,
            type: layer.layer? ? 'layer' : (layer.group? ? 'group' : 'unknown'),
            is_text: text_layer?(layer),
            dimensions: "#{layer.width}x#{layer.height}"
          }
        end,
        groups: group.children_groups.map do |child_group|
          {
            id: child_group.id,
            name: child_group.name,
            visible: child_group.visible?,
            children_count: child_group.children.size
          }
        end
      } : {
        layers: [],
        groups: []
      }
    }

    # 清理空值
    metadata.each do |key, value|
      metadata[key] = clean_hash(value)
    end

    metadata
  end

  def count_text_layers(group)
    group.descendants.count { |node| text_layer?(node) }
  end

  def extract_text_layers_info(group)
    text_layers = []
    group.descendants.each do |node|
      if text_layer?(node)
        text_data = node.layer.text if node.layer.respond_to?(:text)
        text_layers << {
          id: node.id,
          name: node.name,
          visible: node.visible?,
          text_content: text_data ? text_data[:value] : nil,
          font_name: text_data && text_data[:font] ? text_data[:font][:name] : nil,
          font_size: text_data && text_data[:font] ? text_data[:font][:sizes]&.first : nil
        }
      end
    end
    text_layers
  end

  def export_overall_metadata(psd, groups)
    overall_info = {
      psd_info: {
        filename: File.basename(@psd_file_path),
        dimensions: {
          width: psd.header.width,
          height: psd.header.height
        },
        color_mode: {
          code: psd.header.mode,
          name: psd.header.mode_name,
          is_rgb: psd.header.rgb?,
          is_cmyk: psd.header.cmyk?
        },
        channels: psd.header.channels,
        depth: psd.header.depth
      },

      export_info: {
        timestamp: Time.now.iso8601,
        total_groups: groups.size,
        export_directory: @export_dir,
        export_format: "每个组包含两个版本: with_text (包含文字图层) 和 without_text (不包含文字图层)"
      },

      groups_summary: groups.map.with_index do |group, index|
        base_filename = @tracker.generate_filename(group, :group)
        is_real_group = group.respond_to?(:children) && group.respond_to?(:children_layers)
        {
          index: index + 1,
          id: group.id,
          name: group.name,
          path: group.path,
          dimensions: "#{group.width}x#{group.height}",
          position: "(#{group.left}, #{group.top})",
          visible: group.visible?,
          children_count: is_real_group ? group.children.size : 0,
          text_layers_count: count_text_layers(group),
          image_files: {
            with_text: "#{base_filename}/with_text/#{base_filename}_with_text.png",
            without_text: "#{base_filename}/without_text/#{base_filename}_without_text.png"
          },
          metadata_file: "#{base_filename}.json"
        }
      end
    }

    overall_info_path = File.join(@export_dir, 'overall_info.json')
    File.write(overall_info_path, JSON.pretty_generate(overall_info))
    puts "\n总体信息已保存: overall_info.json"
  end


  def clean_hash(hash)
    return nil if hash.nil?

    if hash.is_a?(Hash)
      cleaned = {}
      hash.each do |key, value|
        cleaned_value = clean_hash(value)
        cleaned[key] = cleaned_value unless cleaned_value.nil?
      end
      cleaned.empty? ? nil : cleaned
    elsif hash.is_a?(Array)
      cleaned = hash.map { |item| clean_hash(item) }.compact
      cleaned.empty? ? nil : cleaned
    else
      hash.nil? || (hash.respond_to?(:empty?) && hash.empty?) ? nil : hash
    end
  end

  def safe_call(object, method)
    return nil unless object
    object.respond_to?(method) ? object.send(method) : nil
  end
end

# 主程序
if __FILE__ == $0
  # 使用指定的PSD文件
  psd_file = 'images/c我的備戰盟.psd'

  unless File.exist?(psd_file)
    puts "错误: 找不到PSD文件 #{psd_file}"
    puts "请确保文件存在并位于正确的位置"
    exit 1
  end

  exporter = PSDGroupsExporter.new(psd_file)
  exporter.export_groups
end
