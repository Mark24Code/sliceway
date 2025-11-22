#!/usr/bin/env ruby

require_relative 'psd.rb/lib/psd'

class PSDExporter
  def initialize(psd_file_path, output_dir = 'output')
    @psd_file_path = psd_file_path
    @output_dir = output_dir

    # 确保输出目录存在
    Dir.mkdir(@output_dir) unless Dir.exist?(@output_dir)
  end

  def export_slices
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

      # 导出每个切片
      slices.each_with_index do |slice, index|
        export_slice(slice, index + 1)
      end

      puts "\n切片导出完成! 所有切片已保存到 #{@output_dir}/ 目录"
    end
  rescue => e
    puts "错误: #{e.message}"
    puts e.backtrace.join("\n") if ENV['DEBUG']
  end

  private

  def export_slice(slice, index)
    puts "\n导出切片 #{index}:"
    puts "  名称: #{slice.name || '未命名'}"
    puts "  ID: #{slice.id}"
    puts "  位置: (#{slice.left}, #{slice.top})"
    puts "  尺寸: #{slice.width} x #{slice.height}"

    # 生成文件名
    filename = generate_filename(slice, index)
    output_path = File.join(@output_dir, filename)

    # 导出切片图片
    begin
      # 先调用 to_png 生成 PNG 对象
      png = slice.to_png
      png.save(output_path, :fast_rgba)
      puts "  已保存: #{filename}"
    rescue => e
      puts "  导出失败: #{e.message}"
    end
  end

  def generate_filename(slice, index)
    name = slice.name || "slice_#{index}"
    # 清理文件名中的非法字符
    clean_name = name.gsub(/[^\w\s-]/, '_').gsub(/\s+/, '_')
    "#{clean_name}_#{index}.png"
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
  exporter.export_slices
end