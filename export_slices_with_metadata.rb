#!/usr/bin/env ruby

require_relative 'psd.rb/lib/psd'
require 'json'
require 'digest'

class PSDExporter
  def initialize(psd_file_path, output_base_dir = 'output')
    @psd_file_path = psd_file_path
    @output_base_dir = output_base_dir

    # 创建基础输出目录
    Dir.mkdir(@output_base_dir) unless Dir.exist?(@output_base_dir)
  end

  def export_slices_with_metadata
    puts "正在解析PSD文件: #{@psd_file_path}"

    PSD.open(@psd_file_path) do |psd|
      puts "PSD文件信息:"
      puts "  宽度: #{psd.header.width}"
      puts "  高度: #{psd.header.height}"
      puts "  颜色模式: #{psd.header.mode}"
      puts "  通道数: #{psd.header.channels}"

      # 获取切片
      slices = psd.slices
      puts "\n找到 #{slices.size} 个切片"

      if slices.empty?
        puts "警告: 该PSD文件中没有找到切片"
        return
      end

      # 为本次导出创建时间戳目录
      timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
      @export_dir = File.join(@output_base_dir, "slices_#{timestamp}")
      Dir.mkdir(@export_dir)

      puts "\n导出目录: #{@export_dir}"

      # 创建子目录结构
      @images_dir = File.join(@export_dir, 'images')
      @metadata_dir = File.join(@export_dir, 'metadata')
      Dir.mkdir(@images_dir)
      Dir.mkdir(@metadata_dir)

      # 导出每个切片
      slices.each_with_index do |slice, index|
        export_slice_with_metadata(slice, index + 1, psd)
      end

      # 导出总体信息
      export_overall_metadata(psd, slices)

      puts "\n切片导出完成!"
      puts "  图片目录: #{@images_dir}"
      puts "  元数据目录: #{@metadata_dir}"
      puts "  总体信息: #{File.join(@export_dir, 'overall_info.json')}"
    end
  rescue => e
    puts "错误: #{e.message}"
    puts e.backtrace.join("\n") if ENV['DEBUG']
  end

  private

  def export_slice_with_metadata(slice, index, psd)
    puts "\n导出切片 #{index}:"
    puts "  名称: #{slice.name || '未命名'}"
    puts "  ID: #{slice.id}"
    puts "  位置: (#{slice.left}, #{slice.top})"
    puts "  尺寸: #{slice.width} x #{slice.height}"

    # 生成基础文件名
    base_filename = generate_base_filename(slice, index)

    # 图片文件路径
    image_filename = "#{base_filename}.png"
    image_path = File.join(@images_dir, image_filename)

    # 元数据文件路径
    metadata_filename = "#{base_filename}.json"
    metadata_path = File.join(@metadata_dir, metadata_filename)

    # 导出切片图片
    begin
      png = slice.to_png
      png.save(image_path, :fast_rgba)
      puts "  图片已保存: #{image_filename}"
    rescue => e
      puts "  图片导出失败: #{e.message}"
      return
    end

    # 生成并导出元数据
    begin
      metadata = generate_slice_metadata(slice, index, psd, image_filename)
      File.write(metadata_path, JSON.pretty_generate(metadata))
      puts "  元数据已保存: #{metadata_filename}"
    rescue => e
      puts "  元数据导出失败: #{e.message}"
    end
  end

  def generate_slice_metadata(slice, index, psd, image_filename)
    # 基础切片信息
    metadata = {
      slice_info: {
        id: slice.id,
        name: slice.name,
        group_id: slice.group_id,
        origin: slice.origin,
        associated_layer_id: slice.associated_layer_id,
        type: slice.type,
        index: index
      },

      geometry: {
        bounds: {
          left: slice.left,
          top: slice.top,
          right: slice.right,
          bottom: slice.bottom
        },
        dimensions: {
          width: slice.width,
          height: slice.height
        },
        position: {
          x: slice.left,
          y: slice.top
        }
      },

      web_info: {
        url: slice.url,
        target: slice.target,
        message: slice.message,
        alt: slice.alt,
        cell_text_is_html: slice.cell_text_is_html,
        cell_text: slice.cell_text,
        horizontal_alignment: slice.horizontal_alignment,
        vertical_alignment: slice.vertical_alignment
      },

      appearance: {
        color: slice.color,
        outset: slice.outset
      },

      file_info: {
        image_filename: image_filename,
        metadata_filename: "#{generate_base_filename(slice, index)}.json",
        export_timestamp: Time.now.iso8601
      },

      # 关联图层信息
      associated_layer: extract_associated_layer_info(slice)
    }

    # 清理空值
    metadata.each do |key, value|
      metadata[key] = clean_hash(value)
    end

    metadata
  end

  def extract_layer_info(layer)
    return nil unless layer

    # 安全地提取图层信息，避免调用不存在的方法
    layer_info = {
      id: safe_call(layer, :id),
      name: safe_call(layer, :name),
      visible: safe_call(layer, :visible?),
      opacity: safe_call(layer, :opacity),
      blending_mode: safe_call(layer, :blending_mode),

      geometry: {
        left: safe_call(layer, :left),
        top: safe_call(layer, :top),
        right: safe_call(layer, :right),
        bottom: safe_call(layer, :bottom),
        width: safe_call(layer, :width),
        height: safe_call(layer, :height)
      }
    }

    # 安全地提取蒙版信息
    if safe_call(layer, :mask)
      mask = layer.mask
      layer_info[:mask] = {
        width: safe_call(mask, :width),
        height: safe_call(mask, :height),
        left: safe_call(mask, :left),
        top: safe_call(mask, :top),
        right: safe_call(mask, :right),
        bottom: safe_call(mask, :bottom)
      }
    end

    # 安全地提取图层类型信息
    layer_info[:layer_type] = {
      is_layer: safe_call(layer, :layer?),
      is_group: safe_call(layer, :group?),
      is_folder: safe_call(layer, :folder?),
      is_text: safe_call(layer, :text?),
      is_adjustment: safe_call(layer, :adjustment?)
    }

    # 安全地提取文本信息
    if safe_call(layer, :text?) && safe_call(layer, :text)
      layer_info[:text_info] = layer.text
    end

    layer_info
  end

  def extract_node_info(node)
    return nil unless node

    # 安全地提取节点信息
    node_info = {
      class: node.class.to_s,
      name: safe_call(node, :name),
      visible: safe_call(node, :visible?),
      opacity: safe_call(node, :opacity),
      blending_mode: safe_call(node, :blending_mode)
    }

    # 尝试提取几何信息
    if safe_call(node, :left)
      node_info[:geometry] = {
        left: safe_call(node, :left),
        top: safe_call(node, :top),
        right: safe_call(node, :right),
        bottom: safe_call(node, :bottom),
        width: safe_call(node, :width),
        height: safe_call(node, :height)
      }
    end

    # 尝试提取图层类型信息
    node_info[:node_type] = {
      is_root: safe_call(node, :root?),
      is_layer: safe_call(node, :layer?),
      is_group: safe_call(node, :group?)
    }

    node_info
  rescue => e
    # 如果提取节点信息失败，返回基本信息
    {
      class: node.class.to_s,
      error: "无法提取完整节点信息: #{e.message}"
    }
  end

  def extract_associated_layer_info(slice)
    # 检查是否有有效的关联图层
    return nil unless slice.associated_layer_id && !slice.associated_layer_id.to_s.empty?

    layer = slice.associated_layer
    return nil unless layer

    # 如果是根节点（没有实际关联图层），返回特殊标记
    if layer.is_a?(PSD::Node::Root)
      return {
        type: 'root_node',
        description: '切片没有关联到特定图层，返回文档根节点',
        document_dimensions: {
          width: layer.left ? layer.right - layer.left : nil,
          height: layer.top ? layer.bottom - layer.top : nil
        }
      }
    end

    # 如果是真正的图层，提取信息
    extract_node_info(layer)
  rescue => e
    {
      error: "无法提取关联图层信息: #{e.message}",
      layer_class: layer.class.to_s,
      associated_layer_id: slice.associated_layer_id
    }
  end

  def safe_call(object, method)
    return nil unless object
    object.respond_to?(method) ? object.send(method) : nil
  end

  def export_overall_metadata(psd, slices)
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
        depth: psd.header.depth,
        is_big_document: psd.header.big?
      },

      export_info: {
        timestamp: Time.now.iso8601,
        total_slices: slices.size,
        export_directory: @export_dir
      },

      slices_summary: slices.map.with_index do |slice, index|
        {
          index: index + 1,
          id: slice.id,
          name: slice.name,
          width: slice.width,
          height: slice.height,
          offset_left: slice.left,
          offset_top: slice.top,
          image_file: "#{generate_base_filename(slice, index + 1)}.png",
          metadata_file: "#{generate_base_filename(slice, index + 1)}.json"
        }
      end
    }

    overall_info_path = File.join(@export_dir, 'overall_info.json')
    File.write(overall_info_path, JSON.pretty_generate(overall_info))
    puts "\n总体信息已保存: overall_info.json"
  end

  def generate_base_filename(slice, index)
    # 生成6位hash确保唯一性
    hash = Digest::MD5.hexdigest("#{slice.id}_#{index}_#{Time.now.to_f}")[0..5]

    # 获取名称，如果没有则使用默认名称
    name = slice.name || "slice"

    # 清理文件名：去除非法字符，替换下划线为连字符，去除多余空格
    clean_name = name.gsub(/[^\w\s\u4e00-\u9fa5-]/, '')  # 保留字母、数字、中文、空格、连字符
                   .gsub(/[_\s]+/, '-')                  # 替换下划线和空格为连字符
                   .gsub(/-+/, '-')                      # 合并多个连字符
                   .gsub(/^-|-$/, '')                    # 去除开头和结尾的连字符

    # 格式：id-文件名-6位hash
    "#{slice.id}-#{clean_name}-#{hash}"
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

  exporter = PSDExporter.new(psd_file)
  exporter.export_slices_with_metadata
end
