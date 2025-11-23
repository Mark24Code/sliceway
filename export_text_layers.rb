#!/usr/bin/env ruby

require_relative 'psd.rb/lib/psd'
require 'json'
require 'digest'
require_relative 'progress_bar'
require_relative 'export_tracker'

class PSDTextLayersExporter
  def initialize(psd_file_path, output_base_dir = 'output')
    @psd_file_path = psd_file_path
    @output_base_dir = output_base_dir
    @tracker = ExportTracker.new

    # 创建基础输出目录
    Dir.mkdir(@output_base_dir) unless Dir.exist?(@output_base_dir)
  end

  def export_text_layers
    puts "正在解析PSD文件: #{@psd_file_path}"

    PSD.open(@psd_file_path) do |psd|
      # puts "PSD文件信息:"
      # puts "  宽度: #{psd.header.width}"
      # puts "  高度: #{psd.header.height}"
      # puts "  颜色模式: #{psd.header.mode_name}"
      # puts "  通道数: #{psd.header.channels}"

      # 获取所有文字图层
      text_layers = psd.tree.descendant_layers.select { |layer| !layer.info[:type].nil? }
      # puts "\n找到 #{text_layers.size} 个文字图层"

      if text_layers.empty?
        puts "警告: 该PSD文件中没有找到文字图层"
        return
      end

      # 为本次导出创建时间戳目录
      timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
      @export_dir = File.join(@output_base_dir, "text_layers_#{timestamp}")
      Dir.mkdir(@export_dir)

      # puts "\n导出目录: #{@export_dir}"

      # 创建子目录结构
      @images_dir = File.join(@export_dir, 'images')
      @metadata_dir = File.join(@export_dir, 'metadata')
      Dir.mkdir(@images_dir)
      Dir.mkdir(@metadata_dir)

      # 创建进度条
      progress = ProgressBar.new(text_layers.size, prefix: "导出文字图层", width: 40)

      # 导出每个文字图层
      text_layers.each_with_index do |layer, index|
        export_text_layer_with_metadata(layer, index + 1, psd)
        progress.increment(1)
      end

      progress.finish("文字图层导出完成")

      # 导出总体信息
      export_overall_metadata(psd, text_layers)

      puts "\n文字图层导出完成!"
      puts "  图片目录: #{@images_dir}"
      puts "  元数据目录: #{@metadata_dir}"
      puts "  总体信息: #{File.join(@export_dir, 'overall_info.json')}"
    end
  rescue => e
    puts "错误: #{e.message}"
    puts e.backtrace.join("\n") if ENV['DEBUG']
  end

  private

  def export_text_layer_with_metadata(layer, index, psd)
    # puts "\n导出文字图层 #{index}:"
    # puts "  名称: #{layer.name || '未命名'}"
    # puts "  位置: (#{layer.left}, #{layer.top})"
    # puts "  尺寸: #{layer.width} x #{layer.height}"
    # puts "  可见性: #{layer.visible? ? '可见' : '隐藏'}"

    # 生成基础文件名
    base_filename = @tracker.generate_filename(layer, :text_layer)

    # 图片文件路径
    image_filename = "#{base_filename}.png"
    image_path = File.join(@images_dir, image_filename)

    # 元数据文件路径
    metadata_filename = "#{base_filename}.json"
    metadata_path = File.join(@metadata_dir, metadata_filename)

    # 导出文字图层图片
    begin
      png = layer.to_png
      png.save(image_path, :fast_rgba)
      # puts "  图片已保存: #{image_filename}"
    rescue => e
      puts "  图片导出失败: #{e.message}"
      return
    end

    # 生成并导出元数据
    begin
      metadata = generate_text_layer_metadata(layer, index, psd, image_filename)
      File.write(metadata_path, JSON.pretty_generate(metadata))
      # puts "  元数据已保存: #{metadata_filename}"
    rescue => e
      puts "  元数据导出失败: #{e.message}"
    end
  end

  def generate_text_layer_metadata(layer, index, psd, image_filename)
    text_data = layer.text

    metadata = {
      layer_info: {
        id: layer.id,
        name: layer.name,
        index: index,
        path: layer.path,
        depth: layer.depth
      },

      visibility_and_appearance: {
        visible: layer.visible?,
        opacity: layer.opacity,
        blending_mode: layer.blending_mode
      },

      geometry: {
        bounds: {
          left: layer.left,
          top: layer.top,
          right: layer.right,
          bottom: layer.bottom
        },
        dimensions: {
          width: layer.width,
          height: layer.height
        },
        position: {
          x: layer.left,
          y: layer.top
        }
      },

      text_content: {
        value: text_data[:value],
        text_box: {
          left: text_data[:left],
          top: text_data[:top],
          right: text_data[:right],
          bottom: text_data[:bottom]
        },
        transform: text_data[:transform]
      },

      font_info: {
        font_name: text_data[:font][:name],
        font_sizes: text_data[:font][:sizes],
        font_colors: text_data[:font][:colors],
        css_styles: text_data[:font][:css]
      },

      layer_properties: {
        has_mask: !layer.mask.nil?,
        mask_info: layer.mask ? {
          width: layer.mask.width,
          height: layer.mask.height,
          bounds: {
            left: layer.mask.left,
            top: layer.mask.top,
            right: layer.mask.right,
            bottom: layer.mask.bottom
          }
        } : nil,
        parent_path: layer.parent ? layer.parent.path : '根节点'
      },

      file_info: {
        image_filename: image_filename,
        metadata_filename: "#{base_filename}.json",
        export_timestamp: Time.now.iso8601
      }
    }

    # 清理空值
    metadata.each do |key, value|
      metadata[key] = clean_hash(value)
    end

    metadata
  end

  def export_overall_metadata(psd, text_layers)
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
        total_text_layers: text_layers.size,
        export_directory: @export_dir
      },

      text_layers_summary: text_layers.map.with_index do |layer, index|
        text_data = layer.text
        filename = @tracker.generate_filename(layer, :text_layer)
        {
          index: index + 1,
          id: layer.id,
          name: layer.name,
          path: layer.path,
          text_content: text_data[:value] ? text_data[:value][0..50] + (text_data[:value].length > 50 ? '...' : '') : '',
          font_name: text_data[:font][:name],
          font_size: text_data[:font][:sizes]&.first,
          dimensions: "#{layer.width}x#{layer.height}",
          position: "(#{layer.left}, #{layer.top})",
          visible: layer.visible?,
          image_file: "#{filename}.png",
          metadata_file: "#{filename}.json"
        }
      end,

      # 字体统计
      font_statistics: calculate_font_statistics(text_layers)
    }

    overall_info_path = File.join(@export_dir, 'overall_info.json')
    File.write(overall_info_path, JSON.pretty_generate(overall_info))
    puts "\n总体信息已保存: overall_info.json"
  end

  def calculate_font_statistics(text_layers)
    fonts = {}

    text_layers.each do |layer|
      text_data = layer.text
      font_name = text_data[:font][:name]
      font_size = text_data[:font][:sizes]&.first

      if fonts[font_name]
        fonts[font_name][:count] += 1
        fonts[font_name][:sizes] << font_size if font_size
      else
        fonts[font_name] = {
          count: 1,
          sizes: font_size ? [font_size] : []
        }
      end
    end

    fonts.map do |font_name, data|
      {
        font_name: font_name,
        usage_count: data[:count],
        size_range: data[:sizes].empty? ? nil : {
          min: data[:sizes].min,
          max: data[:sizes].max,
          average: data[:sizes].sum / data[:sizes].size.to_f
        }
      }
    end
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

  exporter = PSDTextLayersExporter.new(psd_file)
  exporter.export_text_layers
end
