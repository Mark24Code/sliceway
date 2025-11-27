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

  def export_full_preview(psd)
    path = File.join(@output_dir, "full_preview.png")
    psd.image.save_as_png(path)
  end

  def export_slices(psd)
    psd.slices.each do |slice|
      filename = "slice_#{slice.id}_#{SecureRandom.hex(4)}.png"
      path = File.join(@output_dir, filename)
      
      # slice.to_png.save(path, :fast_rgba) 
      # Note: slice.to_png might return nil if empty or invalid, wrap in rescue
      begin
        png = slice.to_png
        next unless png
        png.save(path, :fast_rgba)
        
        Layer.create!(
          project_id: @project.id,
          resource_id: slice.id.to_s,
          name: slice.name,
          layer_type: 'slice',
          x: slice.left,
          y: slice.top,
          width: slice.width,
          height: slice.height,
          image_path: relative_path(filename)
        )
      rescue => e
        puts "Failed to export slice #{slice.name}: #{e.message}"
      end
    end
  end

  def process_node(node, parent_id = nil)
    # Skip root node itself if it's just the container, but we need its children
    if node.root?
      node.children.each { |child| process_node(child, parent_id) }
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
      metadata: {}
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
    path_with = File.join(@output_dir, filename_with)
    node.image.save_as_png(path_with) rescue nil # Group image might be empty if not composed? 
    # Actually node.image on a group usually returns the composite if parsed with proper options, 
    # or we might need node.to_png. Let's use to_png which is safer.
    
    begin
      node.to_png.save(path_with, :fast_rgba)
      attrs[:image_path] = relative_path(filename_with)
    rescue
      # If group is empty or fails
    end

    # Export without text (using logic from export_groups.rb)
    filename_without = "group_#{node.id}_no_text_#{SecureRandom.hex(4)}.png"
    path_without = File.join(@output_dir, filename_without)
    
    begin
      png = render_group_without_text(node)
      png.save(path_without, :fast_rgba)
      attrs[:metadata][:image_path_no_text] = relative_path(filename_without)
    rescue => e
      # puts "Failed no-text export: #{e.message}"
    end
  end

  def handle_text(node, attrs)
    if node.text
      attrs[:content] = node.text[:value]
      attrs[:metadata][:font] = node.text[:font]
    end
    # Text layers also have an image representation usually
    filename = "text_#{node.id}_#{SecureRandom.hex(4)}.png"
    path = File.join(@output_dir, filename)
    begin
      node.to_png.save(path, :fast_rgba)
      attrs[:image_path] = relative_path(filename)
    rescue
    end
  end

  def handle_layer(node, attrs)
    filename = "layer_#{node.id}_#{SecureRandom.hex(4)}.png"
    path = File.join(@output_dir, filename)
    begin
      node.to_png.save(path, :fast_rgba)
      attrs[:image_path] = relative_path(filename)
    rescue
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
end
