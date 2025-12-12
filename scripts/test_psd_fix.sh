#!/bin/bash
# 测试 PSD 处理修复

set -e

echo "=== PSD 处理修复验证 ==="
echo ""

# 使用 Go 直接测试 PSD 解析
cat > /tmp/test_psd_tree.go << 'EOF'
package main

import (
	"fmt"
	"github.com/Mark24Code/psd"
)

func main() {
	testFile := "./source/psd/testdata/example.psd"

	fmt.Println("=== PSD 树结构测试 ===\n")

	psdFile, err := psd.New(testFile)
	if err != nil {
		fmt.Printf("❌ 打开失败: %v\n", err)
		return
	}
	defer psdFile.Close()

	err = psdFile.Parse()
	if err != nil {
		fmt.Printf("❌ 解析失败: %v\n", err)
		return
	}

	tree := psdFile.Tree()
	if tree == nil {
		fmt.Println("❌ 无法构建树")
		return
	}

	fmt.Printf("✓ 根节点: %s\n", tree.Name)
	fmt.Printf("✓ 直接子节点: %d 个\n", len(tree.Children))
	fmt.Printf("✓ 所有后代: %d 个\n\n", len(tree.Descendants()))

	// 递归打印树结构
	var printNode func(*psd.Node, int)
	printNode = func(node *psd.Node, depth int) {
		indent := ""
		for i := 0; i < depth; i++ {
			indent += "  "
		}

		nodeType := node.Type
		if node.IsTextLayer() {
			nodeType = "text"
		}

		visible := ""
		if !node.Visible {
			visible = " [隐藏]"
		}

		fmt.Printf("%s- %s (%s) %dx%d%s\n",
			indent, node.Name, nodeType, node.Width(), node.Height(), visible)

		for _, child := range node.Children {
			printNode(child, depth+1)
		}
	}

	fmt.Println("树结构:")
	for _, child := range tree.Children {
		printNode(child, 0)
	}

	// 统计各类型节点
	groups := 0
	layers := 0
	textLayers := 0

	for _, node := range tree.Descendants() {
		if node.Type == "group" {
			groups++
		} else if node.IsTextLayer() {
			textLayers++
		} else {
			layers++
		}
	}

	fmt.Printf("\n统计:\n")
	fmt.Printf("  组: %d\n", groups)
	fmt.Printf("  文本图层: %d\n", textLayers)
	fmt.Printf("  普通图层: %d\n", layers)
	fmt.Printf("  总计: %d\n", groups+textLayers+layers)
}
EOF

echo "1. 测试 PSD 树结构解析..."
GOPROXY=https://goproxy.cn,direct go run /tmp/test_psd_tree.go

echo ""
echo "=== 测试完成 ==="
