package handler

import (
	"net/http"
	"os"
	"path/filepath"
	"sort"

	"github.com/gin-gonic/gin"
)

type SystemHandler struct {
	version string
}

func NewSystemHandler(version string) *SystemHandler {
	return &SystemHandler{version: version}
}

// GetVersion handles GET /api/version
func (h *SystemHandler) GetVersion(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"version":     h.version,
		"name":        "Sliceway",
		"description": "现代化的 Photoshop 文件处理和导出工具",
	})
}

// GetDirectories handles GET /api/system/directories
func (h *SystemHandler) GetDirectories(c *gin.Context) {
	currentPath := c.Query("path")
	if currentPath == "" {
		currentPath, _ = os.Getwd()
	}

	// Normalize path
	currentPath, err := filepath.Abs(currentPath)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid path"})
		return
	}

	// Get parent path
	parentPath := filepath.Dir(currentPath)

	// List directories
	entries, err := os.ReadDir(currentPath)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to list directories"})
		return
	}

	var directories []string
	for _, entry := range entries {
		if entry.IsDir() && entry.Name() != "." && entry.Name() != ".." {
			directories = append(directories, entry.Name())
		}
	}

	sort.Strings(directories)

	c.JSON(http.StatusOK, gin.H{
		"current_path": currentPath,
		"parent_path":  parentPath,
		"directories":  directories,
		"sep":          string(filepath.Separator),
	})
}
