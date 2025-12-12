package main

import (
	"fmt"
	"image/color"
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

	fmt.Printf("=== DEBUG Renderer Step by Step ===\n")
	fmt.Printf("Layer: %s\n", targetNode.Name)
	fmt.Printf("Position: (%d, %d)\n", targetNode.Left, targetNode.Top)
	fmt.Printf("Size: %dx%d\n", targetNode.Width(), targetNode.Height())
	fmt.Printf("Blend mode: %s\n", targetNode.Layer.BlendModeKey)
	fmt.Printf("Opacity: %d\n", targetNode.Layer.Opacity)
	fmt.Printf("Fill Opacity: %d\n", targetNode.Layer.FillOpacity())

	// Check mask
	if targetNode.Layer.Mask != nil && !targetNode.Layer.Mask.IsEmpty() {
		fmt.Printf("Mask: %dx%d at (%d, %d)\n",
			targetNode.Layer.Mask.Width(), targetNode.Layer.Mask.Height(),
			targetNode.Layer.Mask.Left, targetNode.Layer.Mask.Top)
	}

	// Get raw layer image
	layerImg, err := targetNode.Layer.ToImage()
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("\n=== Step 1: Raw Layer Image ===\n")
	testX, testY := 100, 100
	rawR, rawG, rawB, rawA := layerImg.At(testX, testY).RGBA()
	fmt.Printf("Pixel at (%d,%d): R=%d, G=%d, B=%d, A=%d\n",
		testX, testY, rawR>>8, rawG>>8, rawB>>8, rawA>>8)

	// Get mask data
	var maskData []byte
	if targetNode.Layer.Mask != nil && !targetNode.Layer.Mask.IsEmpty() {
		if ch, exists := targetNode.Layer.Channels()[-2]; exists {
			maskData = ch.Data
			fmt.Printf("\n=== Step 2: Mask Data ===\n")
			fmt.Printf("Mask data length: %d bytes\n", len(maskData))

			// Calculate mask coordinates for test pixel
			maskWidth := int(targetNode.Layer.Mask.Width())
			maskHeight := int(targetNode.Layer.Mask.Height())
			maskX := testX - int(targetNode.Layer.Mask.Left-targetNode.Layer.Left)
			maskY := testY - int(targetNode.Layer.Mask.Top-targetNode.Layer.Top)

			fmt.Printf("Mask size: %dx%d\n", maskWidth, maskHeight)
			fmt.Printf("Layer position: (%d, %d)\n", targetNode.Layer.Left, targetNode.Layer.Top)
			fmt.Printf("Mask position: (%d, %d)\n", targetNode.Layer.Mask.Left, targetNode.Layer.Mask.Top)
			fmt.Printf("Test pixel layer coord: (%d, %d)\n", testX, testY)
			fmt.Printf("Test pixel mask coord: (%d, %d)\n", maskX, maskY)

			if maskX >= 0 && maskX < maskWidth && maskY >= 0 && maskY < maskHeight {
				maskIdx := maskY*maskWidth + maskX
				if maskIdx < len(maskData) {
					maskValue := maskData[maskIdx]
					fmt.Printf("Mask value at index %d: %d\n", maskIdx, maskValue)

					// Apply mask to alpha
					newA := (rawA >> 8) * uint32(maskValue) / 255
					fmt.Printf("Alpha after mask: %d -> %d\n", rawA>>8, newA)

					fmt.Printf("\n=== Step 3: After Mask Application ===\n")
					fmt.Printf("Color with mask: R=%d, G=%d, B=%d, A=%d\n",
						rawR>>8, rawG>>8, rawB>>8, newA)
				}
			} else {
				fmt.Printf("Pixel outside mask bounds!\n")
			}
		}
	}

	// Now test full render
	fmt.Printf("\n=== Step 4: Full Render via ToPNG ===\n")
	rendered, err := targetNode.ToPNG()
	if err != nil {
		log.Fatal(err)
	}

	finalR, finalG, finalB, finalA := rendered.At(testX, testY).RGBA()
	fmt.Printf("Final pixel at (%d,%d): R=%d, G=%d, B=%d, A=%d\n",
		testX, testY, finalR>>8, finalG>>8, finalB>>8, finalA>>8)

	// Save
	outFile, err := os.Create("/tmp/go_debug_render.png")
	if err != nil {
		log.Fatal(err)
	}
	defer outFile.Close()
	png.Encode(outFile, rendered)

	fmt.Printf("\nSaved to /tmp/go_debug_render.png\n")
}
