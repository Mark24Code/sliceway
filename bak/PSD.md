# PSD.rb API 文档

PSD.rb 是一个用 Ruby 编写的通用 Photoshop 文件解析器。它允许您以可管理的树结构处理 Photoshop 文档，并获取重要数据。

## 安装

```ruby
# 在 Gemfile 中添加
gem 'psd'

# 然后执行
bundle install

# 或者直接安装
gem install psd
```

## 基本用法

### 加载 PSD 文件

```ruby
require 'psd'

# 方法1: 使用 PSD.new
psd = PSD.new('/path/to/file.psd')
psd.parse!

# 方法2: 使用 PSD.open (推荐)
PSD.open('path/to/file.psd') do |psd|
  # 在这里处理 PSD 数据
  puts psd.tree.to_hash
end

# 方法3: DSL 风格
PSD.open('path/to/file.psd') do
  puts tree.to_hash
end
```

## PSD 对象 API

### 基本信息

```ruby
psd = PSD.new('file.psd')
psd.parse!

# 文档基本信息
psd.width           # => 文档宽度
psd.height          # => 文档高度
psd.header.mode     # => 颜色模式代码
psd.header.mode_name # => 颜色模式名称
psd.header.channels # => 通道数
psd.header.depth    # => 位深度
```

### 颜色模式

```ruby
psd.header.rgb?     # => 是否为 RGB 模式
psd.header.cmyk?    # => 是否为 CMYK 模式
psd.header.big?     # => 是否为大型文档格式
```

## 树结构遍历

### 获取根节点

```ruby
tree = psd.tree  # 获取文档树根节点
```

### 节点遍历方法

```ruby
# 基本遍历
tree.root          # 获取根节点
tree.root?         # 是否为根节点
tree.children      # 获取所有直接子节点
tree.has_children? # 是否有子节点
tree.childless?    # 是否没有子节点

# 层级关系
tree.ancestors     # 获取所有祖先节点（不包括根节点）
tree.siblings      # 获取所有兄弟节点（包括当前节点）
tree.next_sibling  # 获取下一个兄弟节点
tree.prev_sibling  # 获取上一个兄弟节点
tree.has_siblings? # 是否有兄弟节点
tree.only_child?   # 是否为唯一子节点

# 后代节点
tree.descendants   # 获取所有后代节点（不包括当前节点）
tree.subtree       # 获取子树（包括当前节点）
tree.depth         # 计算当前节点深度（根节点为0）
tree.path          # 获取到当前节点的路径
```

### 特定类型节点遍历

```ruby
# 只获取图层
tree.descendant_layers  # 所有后代图层
tree.children_layers    # 直接子图层
tree.sibling_layers     # 兄弟图层

# 只获取文件夹/组
tree.descendant_groups  # 所有后代文件夹
tree.children_groups    # 直接子文件夹
tree.sibling_groups     # 兄弟文件夹
```

### 路径搜索

```ruby
# 通过路径查找节点
psd.tree.children_at_path("Version A/Matte")
psd.tree.children_at_path(["Version A", "Matte"])
```

## 图层数据访问

### 图层基本信息

```ruby
layer = psd.tree.descendant_layers.first

# 基本属性
layer.name          # 图层名称
layer.visible?      # 是否可见
layer.opacity       # 不透明度 (0.0 - 1.0)
layer.blending_mode # 混合模式

# 位置和尺寸
layer.left          # 左边界
layer.top           # 上边界
layer.right         # 右边界
layer.bottom        # 下边界
layer.width         # 宽度
layer.height        # 高度

# 类型判断
layer.layer?        # 是否为图层
layer.group?        # 是否为文件夹/组
layer.folder?       # 是否为文件夹
layer.text?         # 是否为文本图层
layer.adjustment?   # 是否为调整图层
```

### 图层蒙版

```ruby
layer.mask.width    # 蒙版宽度
layer.mask.height   # 蒙版高度
layer.mask.left     # 蒙版左边界
layer.mask.top      # 蒙版上边界
layer.mask.right    # 蒙版右边界
layer.mask.bottom   # 蒙版下边界
```

### 文本图层数据

```ruby
if layer.text?
  text_data = layer.text

  text_data[:value]  # 文本内容
  text_data[:font]   # 字体信息
  text_data[:left]   # 文本框左边界
  text_data[:top]    # 文本框上边界
  text_data[:right]  # 文本框右边界
  text_data[:bottom] # 文本框下边界

  # 字体详细信息
  font_info = text_data[:font]
  font_info[:name]   # 字体名称
  font_info[:sizes]  # 字体大小数组
  font_info[:colors] # 字体颜色数组
  font_info[:css]    # CSS 样式字符串
end
```

## 图层合成

### 获取图层合成信息

```ruby
# 获取所有图层合成
layer_comps = psd.layer_comps
layer_comps.each do |comp|
  puts "Name: #{comp.name}, ID: #{comp.id}"
end

# 按名称或ID过滤图层合成
tree = psd.tree.filter_by_comp('Version A')
tree = psd.tree.filter_by_comp(comp_id)
```

## 切片功能

### 获取切片

```ruby
# 获取所有切片
slices = psd.slices

# 按名称或ID搜索切片
slice = psd.slice_by_id(2)
slices = psd.slices_by_name('Logo')
```

### 切片信息

```ruby
slice = psd.slices.first

slice.name                # 切片名称
slice.id                  # 切片ID
slice.group_id            # 组ID
slice.left                # 左边界
slice.top                 # 上边界
slice.right               # 右边界
slice.bottom              # 下边界
slice.width               # 宽度
slice.height              # 高度
slice.url                 # 关联URL
slice.target              # 目标
slice.message             # 消息
slice.alt                 # 替代文本
slice.associated_layer    # 关联图层
```

### 导出切片

```ruby
# 导出为 PNG
slice.to_png              # 返回 ChunkyPNG 画布对象
slice.save_as_png('output.png') # 保存为 PNG 文件
```

## 导出功能

### 导出树结构为 Hash

```ruby
# 导出整个文档树
hash_data = psd.tree.to_hash

# 导出特定节点
node_hash = layer.to_hash
group_hash = group.to_hash
```

### 导出图像

```ruby
# 导出整个文档为扁平图像
png = psd.image.to_png           # 获取 PNG 数据
psd.image.save_as_png('output.png') # 保存为文件

# 导出图层图像 (需要设置 parse_layer_images: true)
psd = PSD.new('file.psd', parse_layer_images: true)
psd.parse!

layer.image.to_png               # 图层 PNG 数据
layer.image.save_as_png('layer.png') # 保存图层图像

# 导出图层组图像
group.to_png                     # 图层组 PNG 数据
group.save_as_png('group.png')   # 保存图层组图像
```

### 预览构建

```ruby
# 保存图层合成预览
psd.tree.filter_by_comp("Version A").save_as_png('./Version A.png')

# 生成图层组 PNG
psd.tree.children_at_path("Group 1").first.to_png
```

## 资源访问

### 获取各种资源

```ruby
# 参考线
guides = psd.guides

# 图层合成
layer_comps = psd.layer_comps

# 切片
slices = psd.slices

# 直接访问资源
resource = psd.resource(:slices)
resource = psd.resource(:guides)
resource = psd.resource(:layer_comps)
```

## 调试

### 启用调试模式

```bash
# 通过环境变量
PSD_DEBUG=true ruby script.rb

# 在代码中启用
PSD.debug = true
```

## 示例代码

### 基本解析示例

```ruby
require 'psd'

PSD.open('file.psd') do |psd|
  puts "文档信息: #{psd.width}x#{psd.height} #{psd.header.mode_name}"
  puts "图层数量: #{psd.tree.descendant_layers.size}"
  puts "文件夹数量: #{psd.tree.descendant_groups.size}"

  # 遍历所有可见图层
  psd.tree.descendant_layers.each do |layer|
    next unless layer.visible?

    puts "图层: #{layer.name}"
    puts "  位置: (#{layer.left}, #{layer.top})"
    puts "  尺寸: #{layer.width}x#{layer.height}"

    if layer.text?
      puts "  文本: #{layer.text[:value]}"
    end
  end
end
```

### 导出所有图层图像

```ruby
require 'fileutils'
require 'psd'

PSD.open('file.psd', parse_layer_images: true) do |psd|
  psd.tree.descendant_layers.each do |layer|
    # 创建目录结构
    path = layer.path.split('/')[0...-1].join('/')
    FileUtils.mkdir_p("output/#{path}")

    # 导出图层图像
    layer.image.save_as_png "output/#{layer.path}.png"
  end
end
```

### 导出所有切片

```ruby
require 'psd'

PSD.open('file.psd') do |psd|
  psd.slices.each_with_index do |slice, index|
    filename = slice.name ? "#{slice.name}.png" : "slice_#{index}.png"
    slice.save_as_png("output/#{filename}")
  end
end
```

## 注意事项

1. **兼容模式**: 如果文件没有启用兼容模式保存，扁平图像导出可能返回空图像
2. **图像模式**: 目前不支持所有图像模式和深度的图像导出
3. **图层样式**: 不支持渲染所有图层样式
4. **性能**: 对于大型 PSD 文件，解析可能需要较长时间

## 支持的 Photoshop 功能

- ✅ 文档结构
- ✅ 文档尺寸
- ✅ 图层/文件夹尺寸和定位
- ✅ 图层/文件夹名称
- ✅ 图层/文件夹可见性和不透明度
- ✅ 字体数据
- ✅ 文本区域内容
- ✅ 字体名称、大小和颜色
- ✅ 颜色模式和位深度
- ✅ 矢量蒙版数据
- ✅ 扁平图像数据
- ✅ 图层合成
- ✅ 切片

这个文档涵盖了 PSD.rb 库的主要 API 功能和使用方法。您可以根据具体需求选择合适的 API 来处理 Photoshop 文件。