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
	fmt.Printf("Layer size: %dx%d\n", targetNode.Width(), targetNode.Height())

	// Get RAW layer image (layer.ToImage() - now without mask)
	fmt.Printf("\n=== RAW Layer Image (Layer.ToImage - no mask/render) ===\n")
	img, err := targetNode.Layer.ToImage()
	if err != nil {
		log.Fatal(err)
	}

	fmt.Printf("Size: %dx%d\n", img.Bounds().Dx(), img.Bounds().Dy())

	// Save
	outFile, err := os.Create("/tmp/go_RAW_layer.png")
	if err != nil {
		log.Fatal(err)
	}
	defer outFile.Close()
	png.Encode(outFile, img)

	// Sample pixels
	for _, pt := range [][2]int{{100, 100}, {200, 200}, {300, 300}} {
		x, y := pt[0], pt[1]
		if x < img.Bounds().Dx() && y < img.Bounds().Dy() {
			r, g, b, a := img.At(x, y).RGBA()
			fmt.Printf("  (%d, %d): R=%d, G=%d, B=%d, A=%d\n",
				x, y, r>>8, g>>8, b>>8, a>>8)
		}
	}
}
