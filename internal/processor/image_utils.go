package processor

import (
	"fmt"
	"image"
	"image/png"
	"os"
	"path/filepath"

	"github.com/chai2010/webp"
	"github.com/disintegration/imaging"
)

// ImageUtils provides image processing utilities
type ImageUtils struct{}

// SaveScaledImages saves an image at multiple scales (1x, 2x, 4x, etc.)
func (u *ImageUtils) SaveScaledImages(img image.Image, outputDir, baseFilename string, scales []string) (string, error) {
	if img == nil {
		return "", fmt.Errorf("image is nil")
	}

	os.MkdirAll(outputDir, 0755)

	baseName := baseFilename[:len(baseFilename)-len(filepath.Ext(baseFilename))]
	ext := filepath.Ext(baseFilename)

	var savedBasePath string

	for _, scale := range scales {
		var outputPath string
		var scaledImg image.Image

		if scale == "1x" {
			outputPath = filepath.Join(outputDir, baseFilename)
			scaledImg = img
			savedBasePath = baseFilename // Relative path
		} else {
			// Parse scale factor (e.g., "2x" -> 2)
			var factor int
			fmt.Sscanf(scale, "%dx", &factor)
			if factor <= 0 {
				factor = 1
			}

			// Scale image
			bounds := img.Bounds()
			newWidth := bounds.Dx() * factor
			newHeight := bounds.Dy() * factor
			scaledImg = imaging.Resize(img, newWidth, newHeight, imaging.Lanczos)

			filename := fmt.Sprintf("%s@%s%s", baseName, scale, ext)
			outputPath = filepath.Join(outputDir, filename)

			if savedBasePath == "" {
				savedBasePath = filename
			}
		}

		// Save image
		if err := u.SavePNG(scaledImg, outputPath); err != nil {
			return "", fmt.Errorf("failed to save %s: %w", scale, err)
		}
	}

	return savedBasePath, nil
}

// SavePNG saves an image as PNG
func (u *ImageUtils) SavePNG(img image.Image, path string) error {
	file, err := os.Create(path)
	if err != nil {
		return err
	}
	defer file.Close()

	return png.Encode(file, img)
}

// SaveWebP saves an image as WebP
func (u *ImageUtils) SaveWebP(img image.Image, path string, quality float32) error {
	file, err := os.Create(path)
	if err != nil {
		return err
	}
	defer file.Close()

	return webp.Encode(file, img, &webp.Options{
		Lossless: false,
		Quality:  quality,
	})
}

// TrimTransparent trims transparent pixels from edges of image
func (u *ImageUtils) TrimTransparent(img image.Image) (image.Image, error) {
	bounds := img.Bounds()
	minX, minY := bounds.Max.X, bounds.Max.Y
	maxX, maxY := 0, 0
	foundOpaque := false

	// Find bounds of non-transparent pixels
	for y := bounds.Min.Y; y < bounds.Max.Y; y++ {
		for x := bounds.Min.X; x < bounds.Max.X; x++ {
			_, _, _, a := img.At(x, y).RGBA()
			if a > 0 {
				foundOpaque = true
				if x < minX {
					minX = x
				}
				if x > maxX {
					maxX = x
				}
				if y < minY {
					minY = y
				}
				if y > maxY {
					maxY = y
				}
			}
		}
	}

	if !foundOpaque {
		return nil, fmt.Errorf("image is completely transparent")
	}

	// If already tight, return original
	if minX == bounds.Min.X && minY == bounds.Min.Y &&
		maxX == bounds.Max.X-1 && maxY == bounds.Max.Y-1 {
		return img, nil
	}

	// Crop to non-transparent area
	cropRect := image.Rect(minX, minY, maxX+1, maxY+1)
	return imaging.Crop(img, cropRect), nil
}

// ClipToCanvas clips an image to canvas boundaries
func (u *ImageUtils) ClipToCanvas(img image.Image, layerX, layerY, canvasWidth, canvasHeight int) (image.Image, int, int, error) {
	bounds := img.Bounds()
	imgWidth := bounds.Dx()
	imgHeight := bounds.Dy()

	// Calculate intersection
	intersectLeft := max(0, layerX)
	intersectTop := max(0, layerY)
	intersectRight := min(canvasWidth, layerX+imgWidth)
	intersectBottom := min(canvasHeight, layerY+imgHeight)

	// Check if there's intersection
	if intersectRight <= intersectLeft || intersectBottom <= intersectTop {
		return nil, 0, 0, fmt.Errorf("layer is completely outside canvas")
	}

	// Calculate crop area in image coordinates
	cropX := intersectLeft - layerX
	cropY := intersectTop - layerY
	cropWidth := intersectRight - intersectLeft
	cropHeight := intersectBottom - intersectTop

	// If completely inside canvas, return original
	if cropX == 0 && cropY == 0 && cropWidth == imgWidth && cropHeight == imgHeight {
		return img, layerX, layerY, nil
	}

	// Crop image
	cropRect := image.Rect(cropX, cropY, cropX+cropWidth, cropY+cropHeight)
	croppedImg := imaging.Crop(img, cropRect)

	return croppedImg, intersectLeft, intersectTop, nil
}

// AnalyzeTransparency analyzes an image and returns bounds of non-transparent pixels
func (u *ImageUtils) AnalyzeTransparency(img image.Image) (minX, minY, maxX, maxY int, foundOpaque bool) {
	bounds := img.Bounds()
	minX, minY = bounds.Max.X, bounds.Max.Y
	maxX, maxY = 0, 0
	foundOpaque = false

	for y := bounds.Min.Y; y < bounds.Max.Y; y++ {
		for x := bounds.Min.X; x < bounds.Max.X; x++ {
			_, _, _, a := img.At(x, y).RGBA()
			if a > 0 {
				foundOpaque = true
				if x < minX {
					minX = x
				}
				if x > maxX {
					maxX = x
				}
				if y < minY {
					minY = y
				}
				if y > maxY {
					maxY = y
				}
			}
		}
	}

	return
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
