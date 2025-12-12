# PSD 导出功能完整实现总结

## 实现的功能清单

根据用户需求和 Ruby 版本的参考实现，现已完整实现以下功能：

### ✅ 1. 预览图生成
- **文件**: `full_preview.webp`
- **格式**: WebP (质量 75)
- **位置**: `public/processed/{project_id}/full_preview.webp`

### ✅ 2. 优先导出切片 (Slices)
- **支持版本**: v6, v7, v8
- **处理**:
  - 裁切到切片边界
  - 增强模式下去除透明边界
  - 支持多倍率导出 (1x, 2x, 3x)
  - 保存到数据库并关联项目

### ✅ 3. 文本图层 (Text Layers)
- **识别**: 使用 `node.IsTextLayer()` 正确识别
- **内容提取**:
  ```go
  textContent := node.GetTextContent()  // 提取文本内容
  attrs.Content = textContent            // 保存到数据库
  ```
- **字体信息提取**:
  ```go
  if textInfo := node.GetTextInfo(); textInfo != nil {
      fonts := textInfo.Fonts()          // 字体列表
      sizes := textInfo.Sizes()          // 字体大小
      // 保存到 metadata
  }
  ```
- **图像导出**: 文本图层的渲染图像

### ✅ 4. Group 导出（两个版本）
- **含文字版本**: `group_{name}_with_text_{hash}.png`
  - 渲染完整的组，包含所有文本图层
  - 保存到 `image_path`

- **不含文字版本**: `group_{name}_no_text_{hash}.png`
  - 使用 `node.ToPNGWithoutText()` 隐藏文本图层渲染
  - 保存到 `metadata["image_path_no_text"]`
  - 使用相同的边界处理（增强模式下）

### ✅ 5. 树结构完整处理
- **Group 节点**:
  - 总是处理子节点，即使自身尺寸为 0
  - 保持层级关系
  - 递归处理所有后代

- **Layer 节点**:
  - 正确识别类型 (layer, text)
  - 提取图像数据
  - 应用增强模式处理

### ✅ 6. 增强模式 (Aggressive Mode)
当 `project.processing_mode == "aggressive"` 时：

- **透明边界去除**:
  ```go
  bounds := p.utils.AnalyzeTransparency(img)
  if !bounds.FoundOpaque {
      return nil  // 跳过完全透明的图层
  }
  // 裁切到非透明边界
  cropped := cropImage(img, cropRect)
  // 更新坐标和尺寸
  attrs.X += bounds.MinX
  attrs.Y += bounds.MinY
  ```

- **画布裁切**:
  ```go
  clipped, newX, newY, err := p.utils.ClipToCanvas(img, x, y, width, height)
  ```

- **跳过条件**:
  - 完全透明的图层
  - 完全超出画布的图层
  - 裁切后尺寸为 0 的图层

### ✅ 7. 文件名处理（修复乱码）
- **UTF-8 安全处理**:
  ```go
  func sanitizeFilename(name string) string {
      // 替换非法字符
      replacer := strings.NewReplacer("/", "_", "\\", "_", ":", "_", ...)
      sanitized := replacer.Replace(name)

      // 按字符数（不是字节）限制长度
      runes := []rune(sanitized)
      if len(runes) > 50 {
          sanitized = string(runes[:50])
      }
      return sanitized
  }
  ```

- **应用到所有导出**:
  - `group_{safeName}_with_text_{hash}.png`
  - `group_{safeName}_no_text_{hash}.png`
  - `text_{safeName}_{hash}.png`
  - `layer_{safeName}_{hash}.png`

## 处理流程

```
1. 打开 PSD 文件
   └─> 提取文档尺寸 (width, height)

2. 导出完整预览
   └─> full_preview.webp

3. 导出切片 (优先)
   └─> 遍历所有 slices
       ├─> 裁切到切片边界
       ├─> 应用增强模式（如果启用）
       └─> 保存多倍率版本

4. 处理树结构
   └─> 遍历根节点的子节点
       ├─> Group 节点
       │   ├─> 导出含文字版本
       │   ├─> 导出不含文字版本
       │   └─> 递归处理所有子节点
       │
       ├─> Text 节点
       │   ├─> 提取文本内容
       │   ├─> 提取字体信息
       │   └─> 导出图像
       │
       └─> Layer 节点
           └─> 导出图像

5. 标记完成
   └─> status = 'ready'
```

## 与 Ruby 版本的对比

| 功能 | Ruby 实现 | Go 实现 | 状态 |
|------|-----------|---------|------|
| **预览图** | ✅ RMagick WebP | ✅ webp.Encode | ✅ 完成 |
| **Slice 导出** | ✅ v6,v7,v8 | ✅ v6,v7,v8 | ✅ 完成 |
| **文本内容提取** | ✅ node.text | ✅ node.GetTextContent() | ✅ 完成 |
| **文本字体信息** | ✅ node.text[:font] | ✅ textInfo.Fonts() | ✅ 完成 |
| **Group 含文字** | ✅ node.to_png | ✅ node.ToPNG() | ✅ 完成 |
| **Group 无文字** | ✅ render_group_without_text | ✅ node.ToPNGWithoutText() | ✅ 完成 |
| **增强模式** | ✅ analyze_png_bounds | ✅ AnalyzeTransparency | ✅ 完成 |
| **画布裁切** | ✅ clip_png_to_canvas | ✅ ClipToCanvas | ✅ 完成 |
| **文件名处理** | ✅ UTF-8 safe | ✅ UTF-8 safe (rune) | ✅ 完成 |
| **多倍率导出** | ✅ 1x,2x,3x | ✅ 1x,2x,3x | ✅ 完成 |
| **树结构遍历** | ✅ 递归处理 | ✅ 递归处理 | ✅ 完成 |

## 关键改进点

### 1. Group 处理逻辑修复
**问题**: Group 节点尺寸为 0 时被跳过，子节点丢失

**修复**:
```go
// 对 Group 特殊处理
if layerType == "group" {
    layerRecord := p.handleGroup(ctx, node, attrs)

    // 关键：无论 Group 是否成功导出，都处理子节点
    for _, child := range node.Children {
        p.processNode(ctx, child, childParentID)
    }
    return
}
```

### 2. 文本图层识别
**问题**: 文本图层被识别为普通 layer

**修复**:
```go
func determineNodeType(node *psd.Node) string {
    // 优先检测文本图层
    if node.IsTextLayer() {
        return "text"
    }
    // ...
}
```

### 3. Group 不含文字版本
**实现**:
```go
// 使用新的 PSD 库 API
imgWithout, err := node.ToPNGWithoutText()
if err == nil && imgWithout != nil {
    // 应用相同的增强模式处理
    // 保存到 metadata["image_path_no_text"]
}
```

### 4. 文本内容提取
**实现**:
```go
// 使用 TypeTool API
textContent := node.GetTextContent()
if textContent != "" {
    attrs.Content = textContent  // 保存到数据库
}

// 提取字体信息
if textInfo := node.GetTextInfo(); textInfo != nil {
    fonts := textInfo.Fonts()
    sizes := textInfo.Sizes()
    // 保存到 metadata
}
```

### 5. 文件名乱码修复
**问题**: 使用字节切片 `name[:100]` 破坏 UTF-8 字符

**修复**:
```go
// 使用 rune 切片确保 UTF-8 安全
runes := []rune(sanitized)
if len(runes) > 50 {
    sanitized = string(runes[:50])
}
```

## 数据库字段说明

### Layer 表
- `project_id`: 项目 ID
- `resource_id`: 资源 ID (slice id 或 node name)
- `name`: 图层名称
- `layer_type`: 类型 (slice/group/text/layer)
- `x, y`: 位置坐标
- `width, height`: 尺寸
- `content`: 文本内容（仅文本图层）
- `image_path`: 主图像路径
- `metadata`: JSON 字段
  - `scales`: 导出倍率 ["1x", "2x", "3x"]
  - `image_path_no_text`: Group 不含文字版本路径
  - `fonts`: 字体列表（文本图层）
  - `font_sizes`: 字体大小列表（文本图层）
  - `opacity`: 不透明度
  - `blend_mode`: 混合模式
- `parent_id`: 父节点 ID（保持树结构）
- `hidden`: 是否隐藏

## 测试验证

### 1. 树结构测试
```bash
bash scripts/test_psd_fix.sh
```
**结果**: 12 个节点全部识别（3 组 + 3 文本 + 6 图层）

### 2. 编译测试
```bash
go build ./cmd/server
```
**结果**: ✅ 编译成功，无警告

### 3. 实际导出测试
```bash
./server
# 上传 PSD 文件
# 检查导出结果
```

**预期结果**:
- ✅ 生成 full_preview.webp
- ✅ 所有 Slices 正确导出
- ✅ 所有文本图层识别并提取内容
- ✅ 所有 Group 导出 2 个版本（含/不含文字）
- ✅ 所有普通图层正确导出
- ✅ 增强模式下正确去除透明边界
- ✅ 文件名无乱码

## 修改的文件

1. **`internal/processor/psd_processor.go`**
   - 重写 `processNode` 函数 (L243-338)
   - 改进 `determineNodeType` 函数 (L370-384)
   - 修复 `sanitizeFilename` 函数 (L401-427)
   - 完善 `handleGroup` 函数 (L436-543) - 添加不含文字版本
   - 完善 `handleText` 函数 (L531-616) - 添加内容和字体提取
   - 修复 `handleLayer` 函数 (L618-677) - 文件名处理

2. **新增功能**
   - Group 不含文字版本导出
   - 文本内容和字体信息提取
   - UTF-8 安全的文件名处理
   - 完整的树结构遍历

## 使用示例

### 上传 PSD 并处理
```go
// 创建项目
project := models.Project{
    PsdPath:         "/path/to/file.psd",
    ProcessingMode:  "aggressive",  // 或 "standard"
    ExportScales:    []string{"1x", "2x", "3x"},
}

// 处理
processor := NewPSDProcessor(project.ID, "./public")
processor.Process(context.Background())
```

### 获取导出结果
```go
// 查询图层
layers := []models.Layer{}
db.Where("project_id = ?", projectID).
   Order("parent_id ASC, id ASC").
   Find(&layers)

// 获取 Group 的两个版本
for _, layer := range layers {
    if layer.LayerType == "group" {
        withText := layer.ImagePath  // 含文字版本
        withoutText := layer.Metadata["image_path_no_text"]  // 不含文字版本
    }
}

// 获取文本内容
for _, layer := range layers {
    if layer.LayerType == "text" {
        text := layer.Content  // 文本内容
        fonts := layer.Metadata["fonts"]  // 字体信息
    }
}
```

## 性能优化

1. **内存管理**: 图像处理后立即释放
2. **并行处理**: Slices 支持并行导出（Ruby 版本逻辑）
3. **增量保存**: 每个图层处理完立即保存到数据库
4. **透明优化**: 增强模式下跳过完全透明的图层

## 错误处理

1. **导出失败**: 记录日志但不中断整个流程
2. **完全透明**: 增强模式下自动跳过
3. **超出画布**: 自动裁切或跳过
4. **文件名冲突**: 使用随机哈希避免

---

**状态**: ✅ 所有功能已完成
**测试**: ✅ 编译通过，等待实际 PSD 测试
**文档**: ✅ 已创建
**修复时间**: 2025-12-12
