package main

import (
	"fmt"
	"log"

	"psd2img/source/psd"
)

func main() {
	// 读取PSD文件
	doc, err := psd.Open("./uploads/1765525860_baibaibai-透明背景.psd")
	if err != nil {
		log.Fatal(err)
	}
	defer doc.Close()

	// 查找图层 "组 110748700" 和其子图层
	findLayer(doc.Layers, "")
}

func findLayer(layers []*psd.Layer, indent string) {
	for _, layer := range layers {
		// 打印图层信息
		if layer.Name == "组 110748700" || layer.Name == "颜色填充 2" || layer.Parent != nil && layer.Parent.Name == "组 110748700" {
			fmt.Printf("%s[%d] %s\n", indent, layer.ID, layer.Name)
			fmt.Printf("%s  Type: %s\n", indent, layer.Type)
			fmt.Printf("%s  BlendMode: %s\n", indent, layer.BlendModeKey)
			fmt.Printf("%s  Opacity: %d\n", indent, layer.Opacity)
			fmt.Printf("%s  Visible: %v\n", indent, layer.Visible)
			fmt.Printf("%s  Bounds: (%d,%d,%d,%d)\n", indent, layer.Left, layer.Top, layer.Right, layer.Bottom)
			fmt.Printf("%s  HasImage: %v\n", indent, layer.HasImage())
			fmt.Printf("%s  Channels: %d\n", indent, len(layer.Channels))
			for i, ch := range layer.Channels {
				fmt.Printf("%s    Channel[%d]: ID=%d, Length=%d\n", indent, i, ch.ID, ch.Length)
			}

			// 检查额外信息
			if layer.AdditionalLayerInfo != nil {
				for key, data := range layer.AdditionalLayerInfo {
					if key == "SoCo" || key == "sofi" {
						fmt.Printf("%s  AdditionalInfo[%s]: %d bytes\n", indent, key, len(data))
					}
				}
			}
			fmt.Println()
		}

		// 递归处理子图层
		if len(layer.Children) > 0 {
			findLayer(layer.Children, indent+"  ")
		}
	}
}
