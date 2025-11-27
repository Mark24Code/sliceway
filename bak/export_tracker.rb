#!/usr/bin/env ruby

require 'digest'
require 'json'

class ExportTracker
  def initialize(history_file = 'export_history.json')
    @history_file = history_file
    @history = load_history
  end

  # 生成8位内容哈希
  def content_hash_8bit(element, type)
    full_hash = content_hash(element, type)
    full_hash[0..7]  # 取前8位
  end

  # 生成文件名：id-name-8位内容哈希
  def generate_filename(element, type)
    element_id = element.id
    name = element.name || ""
    hash_8bit = content_hash_8bit(element, type)

    # 清理名称：去除非法字符，替换下划线和空格为连字符
    clean_name = name.gsub(/[^\w\s\u4e00-\u9fa5-]/, '')  # 保留字母、数字、中文、空格、连字符
                   .gsub(/[_\s]+/, '-')                  # 替换下划线和空格为连字符
                   .gsub(/-+/, '-')                      # 合并多个连字符
                   .gsub(/^-|-$/, '')                    # 去除开头和结尾的连字符

    # 如果名称为空，使用默认名称
    clean_name = "unnamed" if clean_name.empty?

    # 格式：id-文件名-8位hash
    "#{element_id}-#{clean_name}-#{hash_8bit}"
  end

  # 检查是否需要导出
  def needs_export?(element, type)
    element_id = element.id
    return true unless @history[element_id]  # 从未导出过

    # 检查内容是否变化
    current_hash = content_hash(element, type)
    current_hash != @history[element_id][:content_hash]
  end

  # 记录导出
  def record_export(element, type, file_path)
    element_id = element.id
    @history[element_id] = {
      type: type,
      file_path: file_path,
      content_hash: content_hash(element, type),
      attributes_hash: attributes_hash(element, type),
      filename: generate_filename(element, type),
      exported_at: Time.now.iso8601
    }
    save_history
  end

  # 获取已记录的文件名（如果存在）
  def get_recorded_filename(element)
    record = @history[element.id]
    record ? record[:filename] : nil
  end

  private

  # 计算完整内容哈希
  def content_hash(element, type)
    case type
    when :slice
      png_data = element.to_png.to_blob
      Digest::MD5.hexdigest(png_data)
    when :layer
      return Digest::MD5.hexdigest('') unless element.image
      Digest::MD5.hexdigest(element.image.pixel_data.pack('C*'))
    when :group
      # 对于组，可以基于子元素ID列表生成哈希
      child_ids = element.descendants.map(&:id).sort
      Digest::MD5.hexdigest(child_ids.join(','))
    when :text_layer
      # 文字图层基于文本内容和样式生成哈希
      text_data = element.text
      text_info = {
        value: text_data[:value],
        font_name: text_data[:font][:name],
        font_sizes: text_data[:font][:sizes],
        font_colors: text_data[:font][:colors]
      }
      Digest::MD5.hexdigest(text_info.to_json)
    end
  end

  # 计算属性哈希
  def attributes_hash(element, type)
    attributes = case type
    when :slice
      {
        name: element.name,
        bounds: [element.left, element.top, element.right, element.bottom],
        url: element.url,
        target: element.target
      }
    when :layer, :group, :text_layer
      {
        name: element.name,
        position: [element.top, element.left],
        size: [element.width, element.height],
        visible: element.visible?,
        opacity: element.opacity
      }
    end
    Digest::MD5.hexdigest(attributes.to_json)
  end

  def load_history
    File.exist?(@history_file) ? JSON.parse(File.read(@history_file)) : {}
  end

  def save_history
    File.write(@history_file, JSON.pretty_generate(@history))
  end
end