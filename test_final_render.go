package main

import (
	"fmt"
	"image/png"
	"log"
	"os"

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

	// Find 攻城CG图 layer
	var findLayer func(node *psd.Node) *psd.Node
	findLayer = func(node *psd.Node) *psd.Node {
		if node.Name == "攻城CG图" {
			return node
		}
		for _, child := range node.Children {
			if result := findLayer(child); result != nil {
				return result
			}
		}
		return nil
	}

	targetNode := findLayer(file.Tree())
	if targetNode == nil {
		log.Fatal("Layer not found!")
	}

	fmt.Printf("Found layer: %s\n", targetNode.Name)
	fmt.Printf("Blend mode: %s\n", targetNode.Layer.BlendModeKey)
	fmt.Printf("Opacity: %d\n", targetNode.Layer.Opacity)
	fmt.Printf("Fill Opacity: %d\n", targetNode.Layer.FillOpacity())
	fmt.Printf("Calculated Opacity: %d\n", (uint32(targetNode.Layer.Opacity)*uint32(targetNode.Layer.FillOpacity()))/255)

	// Export using NEW renderer
	fmt.Printf("\n=== Exporting with NEW Renderer (Ruby-like) ===\n")
	img, err := targetNode.ToPNG()
	if err != nil {
		log.Fatalf("Failed to render: %v", err)
	}

	// Save image
	outFile, err := os.Create("./go_gongcheng_FINAL.png")
	if err != nil {
		log.Fatal(err)
	}
	defer outFile.Close()

	if err := png.Encode(outFile, img); err != nil {
		log.Fatal(err)
	}
	fmt.Println("Saved to ./go_gongcheng_FINAL.png")

	// Sample pixels
	fmt.Println("\n=== Sample Pixels ===")
	for _, pt := range [][2]int{{100, 100}, {200, 200}, {300, 300}} {
		x, y := pt[0], pt[1]
		if x < img.Bounds().Dx() && y < img.Bounds().Dy() {
			r, g, b, a := img.At(x, y).RGBA()
			fmt.Printf("  (%d, %d): R=%d, G=%d, B=%d, A=%d\n",
				x, y, r>>8, g>>8, b>>8, a>>8)
		}
	}
}
