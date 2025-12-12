package handler

import (
	"net/http"
	"os"
	"path/filepath"
	"psd2img/internal/database"
	"psd2img/internal/models"
	"strconv"

	"github.com/gin-gonic/gin"
)

type ExportHandler struct {
	publicPath string
}

func NewExportHandler(publicPath string) *ExportHandler {
	return &ExportHandler{
		publicPath: publicPath,
	}
}

// ExportLayers handles POST /api/projects/:id/export
func (h *ExportHandler) ExportLayers(c *gin.Context) {
	projectID := c.Param("id")

	var project models.Project
	if err := database.GetDB().First(&project, projectID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Project not found"})
		return
	}

	var req struct {
		LayerIDs       []uint            `json:"layer_ids"`
		Renames        map[string]string `json:"renames"`
		ClearDirectory bool              `json:"clear_directory"`
		TrimTransparent bool             `json:"trim_transparent"`
		Scales         []string          `json:"scales"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
		return
	}

	// Get layers
	var layers []models.Layer
	database.GetDB().Where("id IN ?", req.LayerIDs).Find(&layers)

	if len(layers) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No valid layers found"})
		return
	}

	// Clear export directory if requested
	if req.ClearDirectory {
		os.RemoveAll(project.ExportPath)
	}
	os.MkdirAll(project.ExportPath, 0755)

	// Determine scales to export
	scales := req.Scales
	if len(scales) == 0 {
		scales = []string{"1x"}
	}

	exportCount := 0
	usedFilenames := make(map[string]bool)

	for _, layer := range layers {
		if layer.ImagePath == "" {
			continue
		}

		// Determine base name
		baseName := layer.Name
		if renamed, ok := req.Renames[strconv.FormatUint(uint64(layer.ID), 10)]; ok && renamed != "" {
			baseName = renamed
		}

		// Export each scale
		for _, scale := range scales {
			sourceFile := filepath.Join(h.publicPath, layer.ImagePath)
			ext := filepath.Ext(sourceFile)
			baseNameNoExt := baseName[:max(0, len(baseName)-len(ext))]

			// Determine source file for this scale
			if scale != "1x" {
				// Look for @2x, @4x variants
				dir := filepath.Dir(sourceFile)
				filename := filepath.Base(sourceFile)
				filenameNoExt := filename[:len(filename)-len(ext)]
				sourceFile = filepath.Join(dir, filenameNoExt+"@"+scale+ext)
			}

			// Check if source exists
			if _, err := os.Stat(sourceFile); os.IsNotExist(err) {
				continue
			}

			// Determine target filename
			suffix := ""
			if scale != "1x" {
				suffix = "@" + scale
			}
			targetFilename := baseName + suffix + ext

			// Handle filename conflicts
			if usedFilenames[targetFilename] {
				counter := 1
				for {
					newName := baseNameNoExt + "_" + strconv.Itoa(counter) + suffix + ext
					if !usedFilenames[newName] {
						targetFilename = newName
						break
					}
					counter++
				}
			}
			usedFilenames[targetFilename] = true

			targetPath := filepath.Join(project.ExportPath, targetFilename)

			// Copy file
			if err := copyFile(sourceFile, targetPath); err == nil {
				exportCount++
			}
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"count":   exportCount,
		"path":    project.ExportPath,
	})
}

func copyFile(src, dst string) error {
	input, err := os.ReadFile(src)
	if err != nil {
		return err
	}
	return os.WriteFile(dst, input, 0644)
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}
