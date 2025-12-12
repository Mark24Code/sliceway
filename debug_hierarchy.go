package main

import (
	"fmt"
	"log"

	"github.com/Mark24Code/psd"
)

func main() {
	file, err := psd.New("./baibaibai-透明背景.psd")
	if err != nil {
		log.Fatal(err)
	}
	defer file.Close()

	if err := file.Parse(); err != nil {
		log.Fatal(err)
	}

	// Find 攻城CG图 layer and print its hierarchy
	var findLayer func(node *psd.Node, depth int) *psd.Node
	findLayer = func(node *psd.Node, depth int) *psd.Node {
		indent := ""
		for i := 0; i < depth; i++ {
			indent += "  "
		}
		fmt.Printf("%s%s (Type: %s, Children: %d)\n", indent, node.Name, node.Type, len(node.Children))

		if node.Name == "攻城CG图" {
			fmt.Printf("\n=== FOUND TARGET ===\n")
			fmt.Printf("Name: %s\n", node.Name)
			fmt.Printf("Type: %s\n", node.Type)
			fmt.Printf("Position: (%d, %d)\n", node.Left, node.Top)
			fmt.Printf("Size: %dx%d\n", node.Width(), node.Height())
			fmt.Printf("Children: %d\n", len(node.Children))
			if node.Layer != nil {
				fmt.Printf("Has Layer: Yes\n")
				fmt.Printf("  Blend Mode: %s\n", node.Layer.BlendModeKey)
				fmt.Printf("  Opacity: %d\n", node.Layer.Opacity)
				fmt.Printf("  Channels: %d\n", node.Layer.Channels)
				if node.Layer.Mask != nil {
					fmt.Printf("  Mask: %dx%d at (%d, %d)\n",
						node.Layer.Mask.Width(), node.Layer.Mask.Height(),
						node.Layer.Mask.Left, node.Layer.Mask.Top)
				}
			}
			fmt.Printf("===================\n\n")
			return node
		}

		for _, child := range node.Children {
			if result := findLayer(child, depth+1); result != nil {
				return result
			}
		}
		return nil
	}

	fmt.Println("=== Layer Hierarchy ===")
	targetNode := findLayer(file.Tree(), 0)
	if targetNode == nil {
		log.Fatal("Layer not found!")
	}
}
