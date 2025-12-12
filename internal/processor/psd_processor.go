package processor

import (
	"context"
	"crypto/md5"
	"database/sql"
	"fmt"
	"image"
	"log"
	"os"
	"path/filepath"
	"psd2img/internal/database"
	"psd2img/internal/models"
	"strings"
	"time"

	"github.com/Mark24Code/psd"
)

// PSDProcessor handles PSD file processing
type PSDProcessor struct {
	project    *models.Project
	outputDir  string
	publicPath string
	utils      *ImageUtils
	processedCount int
}

// NewPSDProcessor creates a new PSD processor
func NewPSDProcessor(projectID uint, publicPath string) (*PSDProcessor, error) {
	var project models.Project
	if err := database.GetDB().First(&project, projectID).Error; err != nil {
		return nil, fmt.Errorf("project not found: %w", err)
	}

	outputDir := filepath.Join(publicPath, "processed", fmt.Sprintf("%d", projectID))
	os.MkdirAll(outputDir, 0755)

	return &PSDProcessor{
		project:    &project,
		outputDir:  outputDir,
		publicPath: publicPath,
		utils:      &ImageUtils{},
	}, nil
}

// Process processes the PSD file
func (p *PSDProcessor) Process(ctx context.Context) error {
	db := database.GetDB()

	// Update status
	now := time.Now()
	p.project.Status = "processing"
	p.project.ProcessingStartedAt = &models.NullTime{NullTime: sql.NullTime{Time: now, Valid: true}}
	db.Save(p.project)

	log.Printf("✓ [开始处理] PSD文件: %s\n", p.project.PsdPath)

	// Open and parse PSD
	err := psd.Open(p.project.PsdPath, func(psdDoc *psd.PSD) error {
		// Check context
		if ctx.Err() != nil {
			return ctx.Err()
		}

		// Get header info
		header := psdDoc.Header()
		p.project.Width = int(header.Width())
		p.project.Height = int(header.Height())
		db.Save(p.project)

		log.Printf("✓ [保存尺寸] %d × %d px\n", header.Width(), header.Height())

		// Export full preview
		if err := p.exportFullPreview(ctx, psdDoc); err != nil {
			log.Printf("⚠ [Preview] Warning: %v\n", err)
		}

		// Export slices
		if err := p.exportSlices(ctx, psdDoc); err != nil {
			log.Printf("⚠ [Slices] Warning: %v\n", err)
		}

		// Process layer tree
		tree := psdDoc.Tree()
		if tree != nil {
			p.processNode(ctx, tree, nil)
		}

		return nil
	})

	if err != nil {
		log.Printf("✗ [处理失败] %v\n", err)
		p.project.Status = "error"
		now := time.Now()
		p.project.ProcessingFinishedAt = &models.NullTime{NullTime: sql.NullTime{Time: now, Valid: true}}
		db.Save(p.project)
		return err
	}

	// Mark as ready
	p.project.Status = "ready"
	now = time.Now()
	p.project.ProcessingFinishedAt = &models.NullTime{NullTime: sql.NullTime{Time: now, Valid: true}}
	db.Save(p.project)

	log.Printf("✓ [完成处理] 项目 %d, 共处理 %d 项\n", p.project.ID, p.processedCount)
	return nil
}

func (p *PSDProcessor) exportFullPreview(ctx context.Context, psdDoc *psd.PSD) error {
	if ctx.Err() != nil {
		return ctx.Err()
	}

	log.Println("✓ [Preview] 生成预览图...")

	// Get flattened image
	img := psdDoc.Image()
	if img == nil {
		return fmt.Errorf("no preview image available")
	}

	pngImg := img.ToPNG()
	if pngImg == nil {
		return fmt.Errorf("failed to convert to PNG")
	}

	// Save as WebP
	webpPath := filepath.Join(p.outputDir, "full_preview.webp")
	if err := p.utils.SaveWebP(pngImg, webpPath, 75); err != nil {
		// Fallback to PNG
		pngPath := filepath.Join(p.outputDir, "full_preview.png")
		return p.utils.SavePNG(pngImg, pngPath)
	}

	log.Println("✓ [Preview] 预览图生成成功")
	return nil
}

func (p *PSDProcessor) exportSlices(ctx context.Context, psdDoc *psd.PSD) error {
	if ctx.Err() != nil {
		return ctx.Err()
	}

	slices, err := psdDoc.Slices()
	if err != nil || slices == nil || len(slices.Slices) == 0 {
		return nil // No slices
	}

	log.Printf("✓ [Slices] 发现 %d 个切片\n", len(slices.Slices))

	for _, slice := range slices.Slices {
		if ctx.Err() != nil {
			return ctx.Err()
		}

		// Skip invalid slices
		if slice.Bounds.Right-slice.Bounds.Left <= 0 || slice.Bounds.Bottom-slice.Bounds.Top <= 0 {
			continue
		}

		// Get full image and crop to slice bounds
		img := psdDoc.Image()
		if img == nil {
			continue
		}

		pngImg := img.ToPNG()
		if pngImg == nil {
			continue
		}

		// Crop to slice bounds
		cropRect := image.Rect(
			int(slice.Bounds.Left),
			int(slice.Bounds.Top),
			int(slice.Bounds.Right),
			int(slice.Bounds.Bottom),
		)
		sliceImg := pngImg.SubImage(cropRect).(*image.RGBA)

		// Generate filename based on hash
		hash := fmt.Sprintf("%x", md5.Sum([]byte(fmt.Sprintf("slice_%d_%d", p.project.ID, slice.ID))))[:8]
		filename := fmt.Sprintf("slice_%s.png", hash)

		// Save scaled images
		relativePath, err := p.utils.SaveScaledImages(sliceImg, p.outputDir, filename, p.project.ExportScales)
		if err != nil {
			log.Printf("  ✗ 切片导出失败: %v\n", err)
			continue
		}

		// Create layer record
		sliceName := slice.Name
		if sliceName == "" {
			sliceName = fmt.Sprintf("Slice %d", slice.ID)
		}

		layerRecord := models.Layer{
			ProjectID:  p.project.ID,
			ResourceID: fmt.Sprintf("slice_%d", slice.ID),
			Name:       sliceName,
			LayerType:  "slice",
			X:          int(slice.Bounds.Left),
			Y:          int(slice.Bounds.Top),
			Width:      int(slice.Bounds.Right - slice.Bounds.Left),
			Height:     int(slice.Bounds.Bottom - slice.Bounds.Top),
			ImagePath:  filepath.Join("processed", fmt.Sprintf("%d", p.project.ID), relativePath),
			Metadata: models.Metadata{
				"scales": p.project.ExportScales,
			},
			Hidden: false,
		}

		database.GetDB().Create(&layerRecord)
		log.Printf("  ✓ 导出切片: %s (%dx%d)\n", sliceName, layerRecord.Width, layerRecord.Height)
		p.processedCount++
	}

	return nil
}

func (p *PSDProcessor) processNode(ctx context.Context, node *psd.Node, parentID *uint) {
	// Skip root node itself, process children
	if node.IsRoot() {
		for _, child := range node.Children {
			p.processNode(ctx, child, parentID)
		}
		return
	}

	// Check context
	if ctx.Err() != nil {
		return
	}

	// Skip empty nodes
	if node.Width() <= 0 || node.Height() <= 0 {
		log.Printf("- [跳过节点] %s, 尺寸: %dx%d\n", node.Name, node.Width(), node.Height())
		return
	}

	// Determine layer type
	layerType := p.determineNodeType(node)

	// Prepare layer attributes
	x, y := int(node.Left), int(node.Top)
	width, height := int(node.Width()), int(node.Height())

	// Get node image
	var img image.Image
	var err error

	// For groups, render the group
	if node.Type == "group" {
		img, err = node.ToPNG()
	} else if node.Layer != nil {
		img, err = node.Layer.ToImage()
	}

	if err != nil || img == nil {
		// For groups without image, still create record
		if node.Type == "group" {
			layerRecord := p.createLayerRecord(node, parentID, layerType, x, y, width, height, "")
			if layerRecord != nil {
				// Process children
				for _, child := range node.Children {
					p.processNode(ctx, child, &layerRecord.ID)
				}
			}
		}
		return
	}

	// Apply aggressive mode processing if enabled
	if p.project.ProcessingMode == "aggressive" {
		// Clip to canvas
		clippedImg, newX, newY, clipErr := p.utils.ClipToCanvas(img, x, y, p.project.Width, p.project.Height)
		if clipErr != nil {
			log.Printf("- [跳过%s] %s, 完全超出画布\n", layerType, node.Name)
			return
		}
		img = clippedImg
		x, y = newX, newY

		// Analyze and trim transparency
		minX, minY, maxX, maxY, foundOpaque := p.utils.AnalyzeTransparency(img)
		if !foundOpaque {
			log.Printf("- [跳过%s] %s, 完全透明\n", layerType, node.Name)
			return
		}

		// Crop to non-transparent bounds
		if minX > 0 || minY > 0 || maxX < img.Bounds().Dx()-1 || maxY < img.Bounds().Dy()-1 {
			oldWidth, oldHeight := width, height
			cropRect := image.Rect(minX, minY, maxX+1, maxY+1)
			img = img.(*image.RGBA).SubImage(cropRect).(*image.RGBA)
			x += minX
			y += minY
			width = maxX - minX + 1
			height = maxY - minY + 1
			log.Printf("  [强力裁切] %s: (%dx%d) → (%dx%d)\n", node.Name, oldWidth, oldHeight, width, height)
		}
	}

	// Save scaled images
	filename := fmt.Sprintf("%s_%d_%s.png", layerType, p.project.ID, sanitizeFilename(node.Name))
	relativePath, err := p.utils.SaveScaledImages(img, p.outputDir, filename, p.project.ExportScales)
	if err != nil {
		log.Printf("✗ [导出%s] %s 失败: %v\n", layerType, node.Name, err)
		return
	}

	imagePath := filepath.Join("processed", fmt.Sprintf("%d", p.project.ID), relativePath)

	// Create layer record
	layerRecord := p.createLayerRecord(node, parentID, layerType, x, y, width, height, imagePath)
	if layerRecord == nil {
		return
	}

	log.Printf("✓ [导出%s] %s (%dx%d)\n", layerTypeMap(layerType), node.Name, width, height)
	p.processedCount++

	// Process children if it's a group
	if node.Type == "group" && len(node.Children) > 0 {
		for _, child := range node.Children {
			p.processNode(ctx, child, &layerRecord.ID)
		}
	}
}

func (p *PSDProcessor) createLayerRecord(node *psd.Node, parentID *uint, layerType string, x, y, width, height int, imagePath string) *models.Layer {
	db := database.GetDB()

	layerRecord := &models.Layer{
		ProjectID:  p.project.ID,
		ResourceID: fmt.Sprintf("node_%s", node.Name),
		Name:       node.Name,
		LayerType:  layerType,
		X:          x,
		Y:          y,
		Width:      width,
		Height:     height,
		ImagePath:  imagePath,
		Metadata: models.Metadata{
			"scales":     p.project.ExportScales,
			"opacity":    node.Opacity,
			"blend_mode": node.BlendMode,
		},
		ParentID: parentID,
		Hidden:   !node.Visible,
	}

	if err := db.Create(layerRecord).Error; err != nil {
		log.Printf("✗ 创建图层记录失败: %v\n", err)
		return nil
	}

	return layerRecord
}

func (p *PSDProcessor) determineNodeType(node *psd.Node) string {
	switch node.Type {
	case "group":
		return "group"
	case "layer":
		return "layer"
	default:
		return "layer"
	}
}

func layerTypeMap(t string) string {
	switch t {
	case "slice":
		return "切片"
	case "layer":
		return "图层"
	case "group":
		return "组"
	case "text":
		return "文本"
	default:
		return t
	}
}

func sanitizeFilename(name string) string {
	// Replace invalid filename characters
	replacer := strings.NewReplacer(
		"/", "_",
		"\\", "_",
		":", "_",
		"*", "_",
		"?", "_",
		"\"", "_",
		"<", "_",
		">", "_",
		"|", "_",
	)
	sanitized := replacer.Replace(name)
	if sanitized == "" {
		sanitized = "unnamed"
	}
	// Limit length
	if len(sanitized) > 100 {
		sanitized = sanitized[:100]
	}
	return sanitized
}
