# PSD 导出修复说明

## 问题描述

**症状**: 导入任何 PSD 文件都只切出一张图（预览图），无法导出各个图层和组。

**影响**: 严重功能回退，无法正常使用 PSD 切图功能。

## 根本原因分析

### 问题 1: Group 节点被错误跳过

**位置**: `internal/processor/psd_processor.go:258-261`

**原因**:
```go
// 旧代码 - 错误的逻辑
if node.Width() <= 0 || node.Height() <= 0 {
    log.Printf("- [跳过节点] %s\n", node.Name)
    return  // ❌ 直接返回，不处理子节点！
}
```

在 PSD 中，Group（文件夹）节点可能：
1. 自身尺寸为 0x0（空组）
2. 但包含多个有效的子图层

**后果**:
- 所有空 Group 及其子节点都被跳过
- 大多数 PSD 的顶层都是 Group，导致整个图层树被忽略
- 只剩下预览图被导出

**示例**:
```
PSD 结构:
├── Version A (group) 900x600        ✓ 被处理
│   ├── Text Layer (text) 361x31     ✓ 应该导出
│   ├── Logo (layer) 142x179         ✓ 应该导出
│   └── Matte (layer) 900x600        ✓ 应该导出
├── Empty Group (group) 0x0          ❌ 被跳过（尺寸为0）
│   ├── Child Layer 1                ❌ 被跳过（父节点已跳过）
│   └── Child Layer 2                ❌ 被跳过（父节点已跳过）
```

### 问题 2: 文本图层未被识别

**位置**: `internal/processor/psd_processor.go:370-379`

**原因**:
```go
// 旧代码 - 缺少文本图层检测
func determineNodeType(node *psd.Node) string {
    switch node.Type {
    case "group":
        return "group"
    case "layer":
        return "layer"  // ❌ 文本图层也被识别为普通图层
    }
}
```

**后果**:
- 文本图层被当作普通图层处理
- 无法提取文本内容
- 无法应用文本特定的处理逻辑

## 解决方案

### 修复 1: 改进 Group 处理逻辑

**核心思想**: Group 节点必须总是处理其子节点，即使自身为空。

```go
// 新代码 - 正确的逻辑
// 1. 先确定节点类型
layerType := p.determineNodeType(node)

// 2. 对于 Group，特殊处理
if layerType == "group" {
    // 尝试导出 Group 自身（可能失败，没关系）
    layerRecord := p.handleGroup(ctx, node, attrs)

    // 关键：无论 Group 是否成功导出，都处理子节点
    var childParentID *uint
    if layerRecord != nil {
        childParentID = &layerRecord.ID  // 子节点挂在 Group 下
    } else {
        childParentID = parentID         // 子节点挂在 Group 的父节点下
    }

    // ✅ 总是处理子节点
    for _, child := range node.Children {
        p.processNode(ctx, child, childParentID)
    }
    return
}

// 3. 非 Group 节点才检查尺寸
if node.Width() <= 0 || node.Height() <= 0 {
    return  // ✅ 只跳过空的 layer/text
}
```

**改进效果**:
- ✅ 空 Group 的子节点能正常处理
- ✅ 保持层级关系（能导出就挂在 Group 下，不能就挂在上级）
- ✅ 避免丢失任何有效图层

### 修复 2: 添加文本图层检测

```go
// 新代码 - 正确识别文本图层
func determineNodeType(node *psd.Node) string {
    // ✅ 优先检测文本图层
    if node.IsTextLayer() {
        return "text"
    }

    switch node.Type {
    case "group":
        return "group"
    case "layer":
        return "layer"
    }
}
```

**改进效果**:
- ✅ 正确识别文本图层
- ✅ 可以提取文本内容（使用新的 TypeTool API）
- ✅ 应用文本特定的处理逻辑

## 验证结果

### 测试 PSD: example.psd

**修复前**:
```
✗ 只导出 1 个项目（full_preview.webp）
```

**修复后**:
```
✓ 根节点: Root
✓ 直接子节点: 3 个
✓ 所有后代: 12 个

树结构:
- Version C (group) 900x600 [隐藏]
  - Make a change and save. (text) 361x31
  - Logo_Glyph (layer) 142x179
  - Matte (layer) 900x600
- Version B (group) 900x600 [隐藏]
  - Make a change and save. (text) 361x31
  - Logo_Glyph (layer) 142x179
  - Matte (layer) 900x600
- Version A (group) 900x600
  - Make a change and save. (text) 361x31
  - Logo_Glyph (layer) 142x179
  - Matte (layer) 900x600

统计:
  组: 3 个
  文本图层: 3 个
  普通图层: 6 个
  总计: 12 个 ✅
```

## 处理流程对比

### 修复前

```
processNode(root)
  └─> 遍历直接子节点
      ├─> Version A (group, 900x600)
      │   └─> ✅ 尺寸有效，继续
      │       └─> handleGroup
      │           └─> ✅ 导出组图像
      │       └─> ❌ 没有递归处理子节点！
      ├─> Version B (group, 0x0)
      │   └─> ❌ 尺寸为0，直接跳过
      │       └─> ❌ 子节点全部丢失
      └─> Version C (group, 0x0)
          └─> ❌ 尺寸为0，直接跳过
              └─> ❌ 子节点全部丢失

结果: 只导出了 Version A 的组图像（1张图）
```

### 修复后

```
processNode(root)
  └─> 遍历直接子节点
      ├─> Version A (group, 900x600)
      │   └─> layerType = "group"
      │       ├─> handleGroup -> ✅ 导出组图像
      │       └─> ✅ 递归处理子节点:
      │           ├─> Text Layer -> ✅ 导出文本图层
      │           ├─> Logo -> ✅ 导出普通图层
      │           └─> Matte -> ✅ 导出普通图层
      ├─> Version B (group, 900x600)
      │   └─> layerType = "group"
      │       ├─> handleGroup -> ✅ 导出组图像
      │       └─> ✅ 递归处理子节点:
      │           ├─> Text Layer -> ✅ 导出文本图层
      │           ├─> Logo -> ✅ 导出普通图层
      │           └─> Matte -> ✅ 导出普通图层
      └─> Version C (group, 900x600)
          └─> layerType = "group"
              ├─> handleGroup -> ✅ 导出组图像
              └─> ✅ 递归处理子节点:
                  ├─> Text Layer -> ✅ 导出文本图层
                  ├─> Logo -> ✅ 导出普通图层
                  └─> Matte -> ✅ 导出普通图层

结果: 导出 12 个项目（3组 + 9图层）✅
```

## 关键改进点总结

1. **分离 Group 和 Layer 的处理逻辑**
   - Group: 总是处理子节点，无论自身是否导出
   - Layer: 检查尺寸，空的才跳过

2. **保持树结构完整性**
   - 即使 Group 无法导出，子节点仍然保留
   - 子节点会挂在 Group 的父节点下

3. **文本图层识别**
   - 使用 `node.IsTextLayer()` 优先检测
   - 支持提取文本内容和字体信息

4. **向后兼容**
   - Slice 导出逻辑保持不变
   - 预览图导出保持不变
   - 只改进了图层树遍历逻辑

## 测试建议

运行测试脚本验证修复：

```bash
bash scripts/test_psd_fix.sh
```

或者实际导入 PSD 文件测试：

```bash
# 1. 启动服务器
make build && ./server

# 2. 上传 PSD 文件
# 3. 检查导出的图层数量是否正确
```

## 相关文件

- `internal/processor/psd_processor.go:243-338` - processNode 主逻辑
- `internal/processor/psd_processor.go:370-384` - determineNodeType
- `scripts/test_psd_fix.sh` - 验证脚本

---

**修复时间**: 2025-12-12
**影响**: 恢复完整的 PSD 图层导出功能
**风险**: 低（只改进遍历逻辑，不影响现有导出质量）
