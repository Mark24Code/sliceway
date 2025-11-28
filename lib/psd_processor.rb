require 'psd'
require 'fileutils'
require 'securerandom'
require_relative 'models'

class PsdProcessor
  def initialize(project_id)
    @project = Project.find(project_id)
    @output_dir = File.join("public", "processed", @project.id.to_s)
    FileUtils.mkdir_p(@output_dir)
  end

  def call
    @project.update(status: 'processing')

    begin
      PSD.open(@project.psd_path) do |psd|
        # Extract and save document dimensions
        save_document_dimensions(psd)

        # 1. Export Full Preview
        export_full_preview(psd)

        # 2. Export Slices
        export_slices(psd)

        # 3. Process Tree (Groups, Layers, Text)
        process_node(psd.tree)
      end

      @project.update(status: 'ready')
    rescue => e
      puts "Error processing PSD: #{e.message}"
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
    filename = "full_preview.png"

    begin
      # 添加图像数据验证
      unless psd.image && psd.image.respond_to?(:to_png)
        puts "Warning: Invalid image data for full preview export"
        return
      end

      png_data = psd.image.to_png
      save_scaled_images(png_data, filename)
    rescue => e
      puts "Error exporting full preview: #{e.message}"
      puts e.backtrace
      # 可以考虑在这里实现降级策略
    end
  end

  def export_slices(psd)
    psd.slices.each do |slice|
      # Skip slices with width=0 or height=0
      if slice.width == 0 || slice.height == 0
        puts "Skipping slice #{slice.name} with dimensions #{slice.width}x#{slice.height}"
        next
      end

      filename = "slice_#{slice.id}_#{SecureRandom.hex(4)}.png"

      begin
        png = slice.to_png
        next unless png

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
        puts "Failed to export slice #{slice.name}: #{e.message}"
        puts e.backtrace if e.message.include?('nil')
      end
    end
  end

  def process_node(node, parent_id = nil)
    # Skip root node itself if it's just the container, but we need its children
    if node.root?
      node.children.each { |child| process_node(child, parent_id) }
      return
    end

    # Skip nodes with width=0 or height=0
    if node.width == 0 || node.height == 0
      puts "Skipping node #{node.name} with dimensions #{node.width}x#{node.height}"
      return
    end

    layer_type = determine_type(node)

    # Prepare record attributes
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

    # Handle specific types
    if layer_type == 'group'
      handle_group(node, attrs)
    elsif layer_type == 'text'
      handle_text(node, attrs)
    else # layer
      handle_layer(node, attrs)
    end

    # Save record
    record = Layer.create!(attrs)

    # Recurse if group
    if node.group?
      node.children.each { |child| process_node(child, record.id) }
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
    end

    # Export without text (using logic from export_groups.rb)
    filename_without = "group_#{node.id}_no_text_#{SecureRandom.hex(4)}.png"

    begin
      png = render_group_without_text(node)
      saved_path = save_scaled_images(png, filename_without)
      attrs[:metadata][:image_path_no_text] = saved_path
    rescue => e
      puts "Failed to export group #{node.name} without text: #{e.message}"
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
    group.descendants.each do |node|
      if text_layer?(node)
        visibility_states[node] = node.force_visible
        node.force_visible = false
      end
    end

    begin
      renderer = PSD::Renderer.new(group, render_hidden: true)
      renderer.render!
      png = renderer.to_png
    ensure
      visibility_states.each do |node, state|
        node.force_visible = state
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
      puts "Warning: Invalid PNG data for #{base_filename}"
      return nil
    end

    scales = @project.export_scales || ['1x']
    saved_base_path = nil

    base_name = File.basename(base_filename, ".*")
    ext = File.extname(base_filename)

    scales.each do |scale|
      begin
        if scale == '1x'
          path = File.join(@output_dir, base_filename)
          png.save(path, :fast_rgba)
          saved_base_path = relative_path(base_filename)
        else
          # Calculate new dimensions
          factor = scale.to_i
          new_width = png.width * factor
          new_height = png.height * factor

          # Resize using ChunkyPNG
          # Note: psd.to_png returns a ChunkyPNG::Image
          resized_png = png.resample_nearest_neighbor(new_width, new_height)

          filename = "#{base_name}@#{scale}#{ext}"
          path = File.join(@output_dir, filename)
          resized_png.save(path, :fast_rgba)

          # If 1x is not requested, we still need a base path for preview
          # Use the first generated scale as the "base" path if not set
          saved_base_path ||= relative_path(filename)
        end
      rescue => e
        puts "Error saving scaled image #{base_filename} at scale #{scale}: #{e.message}"
        # 继续处理其他倍率
      end
    end

    saved_base_path
  end
end
