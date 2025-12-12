package processor

import (
	"context"
	"crypto/md5"
	"crypto/rand"
	"database/sql"
	"encoding/hex"
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

// LayerAttributes holds attributes for creating a layer record
type LayerAttributes struct {
	ProjectID  uint
	Name       string
	LayerType  string
	X          int
	Y          int
	Width      int
	Height     int
	Content    string
	ImagePath  string
	ParentID   *uint
	Hidden     bool
	Metadata   models.Metadata
}

// PSDProcessor handles PSD file processing
type PSDProcessor struct {
	project        *models.Project
	outputDir      string
	publicPath     string
	utils          *ImageUtils
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
	attrs := &LayerAttributes{
		ProjectID: p.project.ID,
		Name:      node.Name,
		LayerType: layerType,
		X:         int(node.Left),
		Y:         int(node.Top),
		Width:     int(node.Width()),
		Height:    int(node.Height()),
		ParentID:  parentID,
		Hidden:    !node.Visible,
		Metadata: models.Metadata{
			"scales":     p.project.ExportScales,
			"opacity":    node.Opacity,
			"blend_mode": node.BlendMode,
		},
	}

	// Handle different node types
	var layerRecord *models.Layer
	if layerType == "group" {
		layerRecord = p.handleGroup(ctx, node, attrs)
	} else if layerType == "text" {
		layerRecord = p.handleText(ctx, node, attrs)
	} else {
		layerRecord = p.handleLayer(ctx, node, attrs)
	}

	// If handle returned nil, skip this layer (e.g., fully transparent in aggressive mode)
	if layerRecord == nil && p.project.ProcessingMode == "aggressive" {
		return
	}

	// If we couldn't create the record, return
	if layerRecord == nil {
		return
	}

	log.Printf("✓ [导出%s] %s (%dx%d)\n", layerTypeMap(layerType), node.Name, attrs.Width, attrs.Height)
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

// generateRandomHex generates a random hex string of specified length
func generateRandomHex(n int) string {
	bytes := make([]byte, n)
	rand.Read(bytes)
	return hex.EncodeToString(bytes)
}

// handleGroup processes a group node
func (p *PSDProcessor) handleGroup(ctx context.Context, node *psd.Node, attrs *LayerAttributes) *models.Layer {
	// Export with text (含文本版本)
	filenameWith := fmt.Sprintf("group_%s_with_text_%s.png", node.Name, generateRandomHex(4))
	var imgWith image.Image
	var err error
	var bounds *TransparencyBounds // Declare bounds first

	imgWith, err = node.ToPNG()
	if err != nil || imgWith == nil {
		log.Printf("✗ [导出组(含文本)] %s 失败: %v\n", node.Name, err)
		// Create record without image for groups that fail to render
		return p.createLayerRecordFromAttrs(attrs)
	}

	// Step 1: Clip to canvas
	clipped, newX, newY, clipErr := p.utils.ClipToCanvas(imgWith, attrs.X, attrs.Y, p.project.Width, p.project.Height)
	if clipErr != nil {
		log.Printf("- [跳过组] %s, 完全超出画布\n", node.Name)
		return nil
	}

	imgWith = clipped
	attrs.X = newX
	attrs.Y = newY
	attrs.Width = clipped.Bounds().Dx()
	attrs.Height = clipped.Bounds().Dy()

	// Step 2: Aggressive mode processing
	if p.project.ProcessingMode == "aggressive" {
		minX, minY, maxX, maxY, foundOpaque := p.utils.AnalyzeTransparency(imgWith)
		if !foundOpaque {
			log.Printf("- [跳过组] %s, 完全透明\n", node.Name)
			return nil
		}

		// Store bounds for use with no-text version
		bounds = &TransparencyBounds{
			MinX:        minX,
			MinY:        minY,
			MaxX:        maxX,
			MaxY:        maxY,
			FoundOpaque: foundOpaque,
		}

		// Crop to non-transparent bounds
		if minX > 0 || minY > 0 || maxX < imgWith.Bounds().Dx()-1 || maxY < imgWith.Bounds().Dy()-1 {
			oldWidth, oldHeight := attrs.Width, attrs.Height
			cropRect := image.Rect(minX, minY, maxX+1, maxY+1)
			imgWith = cropImage(imgWith, cropRect)
			attrs.X += minX
			attrs.Y += minY
			attrs.Width = maxX - minX + 1
			attrs.Height = maxY - minY + 1
			log.Printf("  [强力裁切] %s(组-含文本): (%dx%d) → (%dx%d), 偏移: (%d, %d)\n",
				node.Name, oldWidth, oldHeight, attrs.Width, attrs.Height, minX, minY)
		}
	}

	// Save with text version
	savedPath, err := p.utils.SaveScaledImages(imgWith, p.outputDir, filenameWith, p.project.ExportScales)
	if err != nil {
		log.Printf("✗ [导出组(含文本)] %s 失败: %v\n", node.Name, err)
		return nil
	}
	attrs.ImagePath = filepath.Join("processed", fmt.Sprintf("%d", p.project.ID), savedPath)

	// TODO: Export without text version (需要实现 renderGroupWithoutText 逻辑)
	// Ruby 版本通过隐藏文本图层并重新渲染来实现
	// Go PSD 库可能不支持这个功能，暂时跳过
	_ = bounds // Suppress unused variable warning (bounds would be used for no-text version)

	// Create layer record
	return p.createLayerRecordFromAttrs(attrs)
}

// handleText processes a text node
func (p *PSDProcessor) handleText(ctx context.Context, node *psd.Node, attrs *LayerAttributes) *models.Layer {
	// TODO: Extract text content and font info from node
	// The psd library's text extraction API needs to be investigated
	// For now, we'll process it as a regular layer with image

	filename := fmt.Sprintf("text_%s_%s.png", node.Name, generateRandomHex(4))
	var img image.Image
	var err error
	img, err = node.ToPNG()
	if err != nil || img == nil {
		if node.Layer != nil {
			img, err = node.Layer.ToImage()
		}
		if err != nil || img == nil {
			log.Printf("✗ [导出文本] %s 失败: %v\n", node.Name, err)
			return nil
		}
	}

	// Step 1: Clip to canvas
	clipped, newX, newY, clipErr := p.utils.ClipToCanvas(img, attrs.X, attrs.Y, p.project.Width, p.project.Height)
	if clipErr != nil {
		log.Printf("- [跳过文本] %s, 完全超出画布\n", node.Name)
		return nil
	}

	img = clipped // img is already image.Image, no type assertion needed
	attrs.X = newX
	attrs.Y = newY
	attrs.Width = clipped.Bounds().Dx()
	attrs.Height = clipped.Bounds().Dy()

	// Step 2: Aggressive mode processing
	if p.project.ProcessingMode == "aggressive" {
		minX, minY, maxX, maxY, foundOpaque := p.utils.AnalyzeTransparency(img)
		if !foundOpaque {
			log.Printf("- [跳过文本] %s, 完全透明\n", node.Name)
			return nil
		}

		// Crop to non-transparent bounds
		if minX > 0 || minY > 0 || maxX < img.Bounds().Dx()-1 || maxY < img.Bounds().Dy()-1 {
			oldWidth, oldHeight := attrs.Width, attrs.Height
			cropRect := image.Rect(minX, minY, maxX+1, maxY+1)
			img = cropImage(img, cropRect) // Return value is already image.Image
			attrs.X += minX
			attrs.Y += minY
			attrs.Width = maxX - minX + 1
			attrs.Height = maxY - minY + 1
			log.Printf("  [强力裁切] %s(文本): (%dx%d) → (%dx%d), 偏移: (%d, %d)\n",
				node.Name, oldWidth, oldHeight, attrs.Width, attrs.Height, minX, minY)
		}
	}

	// Save scaled images
	savedPath, err := p.utils.SaveScaledImages(img, p.outputDir, filename, p.project.ExportScales)
	if err != nil {
		log.Printf("✗ [导出文本] %s 失败: %v\n", node.Name, err)
		return nil
	}
	attrs.ImagePath = filepath.Join("processed", fmt.Sprintf("%d", p.project.ID), savedPath)

	// Create layer record
	return p.createLayerRecordFromAttrs(attrs)
}

// handleLayer processes a regular layer node
func (p *PSDProcessor) handleLayer(ctx context.Context, node *psd.Node, attrs *LayerAttributes) *models.Layer {
	filename := fmt.Sprintf("layer_%s_%s.png", node.Name, generateRandomHex(4))
	var img image.Image
	var err error

	// Try to get image from node
	if node.Layer != nil {
		img, err = node.Layer.ToImage()
	} else {
		img, err = node.ToPNG()
	}

	if err != nil || img == nil {
		log.Printf("✗ [导出图层] %s 失败: %v\n", node.Name, err)
		return nil
	}

	// Step 1: Clip to canvas
	clipped, newX, newY, clipErr := p.utils.ClipToCanvas(img, attrs.X, attrs.Y, p.project.Width, p.project.Height)
	if clipErr != nil {
		log.Printf("- [跳过图层] %s, 完全超出画布\n", node.Name)
		return nil
	}

	img = clipped
	attrs.X = newX
	attrs.Y = newY
	attrs.Width = clipped.Bounds().Dx()
	attrs.Height = clipped.Bounds().Dy()

	// Step 2: Aggressive mode processing
	if p.project.ProcessingMode == "aggressive" {
		minX, minY, maxX, maxY, foundOpaque := p.utils.AnalyzeTransparency(img)
		if !foundOpaque {
			log.Printf("- [跳过图层] %s, 完全透明\n", node.Name)
			return nil
		}

		// Crop to non-transparent bounds
		if minX > 0 || minY > 0 || maxX < img.Bounds().Dx()-1 || maxY < img.Bounds().Dy()-1 {
			oldWidth, oldHeight := attrs.Width, attrs.Height
			cropRect := image.Rect(minX, minY, maxX+1, maxY+1)
			img = cropImage(img, cropRect)
			attrs.X += minX
			attrs.Y += minY
			attrs.Width = maxX - minX + 1
			attrs.Height = maxY - minY + 1
			log.Printf("  [强力裁切] %s(图层): (%dx%d) → (%dx%d), 偏移: (%d, %d)\n",
				node.Name, oldWidth, oldHeight, attrs.Width, attrs.Height, minX, minY)
		}
	}

	// Save scaled images
	savedPath, err := p.utils.SaveScaledImages(img, p.outputDir, filename, p.project.ExportScales)
	if err != nil {
		log.Printf("✗ [导出图层] %s 失败: %v\n", node.Name, err)
		return nil
	}
	attrs.ImagePath = filepath.Join("processed", fmt.Sprintf("%d", p.project.ID), savedPath)

	// Create layer record
	return p.createLayerRecordFromAttrs(attrs)
}

// TransparencyBounds holds transparency analysis results
type TransparencyBounds struct {
	MinX        int
	MinY        int
	MaxX        int
	MaxY        int
	FoundOpaque bool
}

// cropImage crops an image handling different types
func cropImage(img image.Image, rect image.Rectangle) image.Image {
	switch v := img.(type) {
	case *image.RGBA:
		return v.SubImage(rect)
	case *image.NRGBA:
		return v.SubImage(rect)
	default:
		// Convert to RGBA first
		bounds := img.Bounds()
		rgba := image.NewRGBA(bounds)
		for y := bounds.Min.Y; y < bounds.Max.Y; y++ {
			for x := bounds.Min.X; x < bounds.Max.X; x++ {
				rgba.Set(x, y, img.At(x, y))
			}
		}
		return rgba.SubImage(rect)
	}
}

// createLayerRecordFromAttrs creates a layer record from LayerAttributes
func (p *PSDProcessor) createLayerRecordFromAttrs(attrs *LayerAttributes) *models.Layer {
	db := database.GetDB()

	layerRecord := &models.Layer{
		ProjectID:  attrs.ProjectID,
		ResourceID: fmt.Sprintf("node_%s", attrs.Name),
		Name:       attrs.Name,
		LayerType:  attrs.LayerType,
		X:          attrs.X,
		Y:          attrs.Y,
		Width:      attrs.Width,
		Height:     attrs.Height,
		Content:    attrs.Content,
		ImagePath:  attrs.ImagePath,
		Metadata:   attrs.Metadata,
		ParentID:   attrs.ParentID,
		Hidden:     attrs.Hidden,
	}

	if err := db.Create(layerRecord).Error; err != nil {
		log.Printf("✗ 创建图层记录失败: %v\n", err)
		return nil
	}

	return layerRecord
}

