package handler

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"psd2img/internal/database"
	"psd2img/internal/models"
	"psd2img/internal/processor"
	"psd2img/internal/service"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

type ProjectHandler struct {
	taskManager *service.TaskManager
	uploadsPath string
	exportsPath string
	publicPath  string
}

func NewProjectHandler(tm *service.TaskManager, uploadsPath, exportsPath, publicPath string) *ProjectHandler {
	return &ProjectHandler{
		taskManager: tm,
		uploadsPath: uploadsPath,
		exportsPath: exportsPath,
		publicPath:  publicPath,
	}
}

// ListProjects handles GET /api/projects
func (h *ProjectHandler) ListProjects(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	perPage := 20

	var projects []models.Project
	var total int64

	db := database.GetDB()
	db.Model(&models.Project{}).Count(&total)
	db.Order("created_at DESC").
		Offset((page - 1) * perPage).
		Limit(perPage).
		Find(&projects)

	// Convert to JSON
	projectsJSON := make([]map[string]interface{}, len(projects))
	for i, p := range projects {
		projectJSON := p.AsJSON()
		// Add file_size and layers_count
		if p.PsdPath != "" {
			if info, err := os.Stat(p.PsdPath); err == nil {
				projectJSON["file_size"] = info.Size()
			}
		}
		var layersCount int64
		db.Model(&models.Layer{}).Where("project_id = ?", p.ID).Count(&layersCount)
		projectJSON["layers_count"] = layersCount
		projectsJSON[i] = projectJSON
	}

	c.JSON(http.StatusOK, gin.H{
		"projects": projectsJSON,
		"total":    total,
	})
}

// GetProject handles GET /api/projects/:id
func (h *ProjectHandler) GetProject(c *gin.Context) {
	id := c.Param("id")

	var project models.Project
	if err := database.GetDB().First(&project, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Project not found"})
		return
	}

	projectJSON := project.AsJSON()
	if project.PsdPath != "" {
		if info, err := os.Stat(project.PsdPath); err == nil {
			projectJSON["file_size"] = info.Size()
		}
	}
	var layersCount int64
	database.GetDB().Model(&models.Layer{}).Where("project_id = ?", project.ID).Count(&layersCount)
	projectJSON["layers_count"] = layersCount

	c.JSON(http.StatusOK, projectJSON)
}

// CreateProject handles POST /api/projects
func (h *ProjectHandler) CreateProject(c *gin.Context) {
	// Get uploaded file
	file, err := c.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No file uploaded"})
		return
	}

	// Validate file extension
	filename := file.Filename
	ext := strings.ToLower(filepath.Ext(filename))
	if ext != ".psd" && ext != ".psb" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Only PSD and PSB files are supported"})
		return
	}

	// Save uploaded file
	targetPath := filepath.Join(h.uploadsPath, fmt.Sprintf("%d_%s", time.Now().Unix(), filename))
	if err := c.SaveUploadedFile(file, targetPath); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save file"})
		return
	}

	// Handle export path
	exportPath := c.PostForm("export_path")
	if exportPath == "" {
		exportPath = filepath.Join(h.exportsPath, fmt.Sprintf("%d", time.Now().Unix()))
	} else if !filepath.IsAbs(exportPath) {
		wd, _ := os.Getwd()
		exportPath = filepath.Join(wd, exportPath)
	}

	// Parse export scales
	var exportScales models.StringArray
	if scalesStr := c.PostForm("export_scales"); scalesStr != "" {
		json.Unmarshal([]byte(scalesStr), &exportScales)
	}
	if len(exportScales) == 0 {
		exportScales = models.StringArray{"1x"}
	}

	// Create project record
	project := models.Project{
		Name:           c.DefaultPostForm("name", filename),
		PsdPath:        targetPath,
		ExportPath:     exportPath,
		Status:         "pending",
		ExportScales:   exportScales,
		ProcessingMode: c.PostForm("processing_mode"),
	}

	if err := database.GetDB().Create(&project).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create project"})
		return
	}

	// Start background processing
	h.startProcessing(project.ID)

	c.JSON(http.StatusOK, project.AsJSON())
}

// DeleteProject handles DELETE /api/projects/:id
func (h *ProjectHandler) DeleteProject(c *gin.Context) {
	id := c.Param("id")

	var project models.Project
	// Use Unscoped to include soft-deleted records in search, then hard delete
	if err := database.GetDB().Unscoped().First(&project, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Project not found"})
		return
	}

	// Stop processing if running
	h.taskManager.StopTask(project.ID)

	// Delete associated layers first
	database.GetDB().Unscoped().Where("project_id = ?", project.ID).Delete(&models.Layer{})

	// Delete files
	h.cleanupProjectFiles(&project)

	// Hard delete from database
	if err := database.GetDB().Unscoped().Delete(&project).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete project"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Project deleted successfully"})
}

// BatchDelete handles DELETE /api/projects/batch
func (h *ProjectHandler) BatchDelete(c *gin.Context) {
	var req struct {
		IDs []uint `json:"ids"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
		return
	}

	deletedCount := 0
	var errors []string

	for _, id := range req.IDs {
		var project models.Project
		if err := database.GetDB().Unscoped().First(&project, id).Error; err != nil {
			errors = append(errors, fmt.Sprintf("Project %d not found", id))
			continue
		}

		// Stop processing if running
		h.taskManager.StopTask(project.ID)

		// Delete associated layers first
		database.GetDB().Unscoped().Where("project_id = ?", project.ID).Delete(&models.Layer{})

		// Delete files
		h.cleanupProjectFiles(&project)

		// Hard delete from database
		if err := database.GetDB().Unscoped().Delete(&project).Error; err != nil {
			errors = append(errors, fmt.Sprintf("Failed to delete project %d", id))
			continue
		}

		deletedCount++
	}

	if len(errors) > 0 {
		c.JSON(http.StatusOK, gin.H{
			"success":       deletedCount > 0,
			"deleted_count": deletedCount,
			"errors":        errors,
		})
	} else {
		c.JSON(http.StatusOK, gin.H{
			"success":       true,
			"deleted_count": deletedCount,
			"message":       fmt.Sprintf("Successfully deleted %d projects", deletedCount),
		})
	}
}

// ProcessProject handles POST /api/projects/:id/process
func (h *ProjectHandler) ProcessProject(c *gin.Context) {
	id := c.Param("id")
	projectID, _ := strconv.ParseUint(id, 10, 32)

	var project models.Project
	if err := database.GetDB().First(&project, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Project not found"})
		return
	}

	if project.Status != "pending" {
		c.JSON(http.StatusBadRequest, gin.H{"error": fmt.Sprintf("Cannot process project with status: %s", project.Status)})
		return
	}

	// Update status
	project.Status = "processing"
	database.GetDB().Save(&project)

	// Start processing
	h.startProcessing(uint(projectID))

	c.JSON(http.StatusOK, gin.H{"success": true})
}

// StopProject handles POST /api/projects/:id/stop
func (h *ProjectHandler) StopProject(c *gin.Context) {
	id := c.Param("id")
	projectID, _ := strconv.ParseUint(id, 10, 32)

	var project models.Project
	if err := database.GetDB().First(&project, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Project not found"})
		return
	}

	if project.Status != "processing" {
		c.JSON(http.StatusBadRequest, gin.H{"error": fmt.Sprintf("Cannot stop project with status: %s", project.Status)})
		return
	}

	// Stop task
	if !h.taskManager.StopTask(uint(projectID)) {
		c.JSON(http.StatusNotFound, gin.H{"error": "Task not found"})
		return
	}

	// Clean up generated files and reset status
	publicPath := c.GetString("public_path")
	var layers []models.Layer
	database.GetDB().Where("project_id = ?", project.ID).Find(&layers)

	for _, layer := range layers {
		if layer.ImagePath != "" {
			os.RemoveAll(filepath.Join(publicPath, layer.ImagePath))
		}
	}

	// Delete processed images directory
	processedDir := filepath.Join(publicPath, "processed", fmt.Sprintf("%d", project.ID))
	os.RemoveAll(processedDir)

	// Reset project status
	project.Status = "pending"
	now := time.Now()
	project.ProcessingFinishedAt = &models.NullTime{NullTime: sql.NullTime{Time: now, Valid: true}}
	database.GetDB().Save(&project)

	// Delete layer records
	database.GetDB().Where("project_id = ?", project.ID).Delete(&models.Layer{})

	c.JSON(http.StatusOK, gin.H{"success": true})
}

func (h *ProjectHandler) startProcessing(projectID uint) {
	h.taskManager.StartTask(projectID, func(ctx context.Context) error {
		log.Printf("Starting processing for project %d\n", projectID)

		// Update status
		db := database.GetDB()
		var project models.Project
		db.First(&project, projectID)

		now := time.Now()
		project.Status = "processing"
		project.ProcessingStartedAt = &models.NullTime{NullTime: sql.NullTime{Time: now, Valid: true}}
		db.Save(&project)

		// Create PSD processor and run
		processor, err := processor.NewPSDProcessor(projectID, h.publicPath)
		if err != nil {
			log.Printf("Failed to create processor: %v\n", err)
			project.Status = "error"
			now := time.Now()
			project.ProcessingFinishedAt = &models.NullTime{NullTime: sql.NullTime{Time: now, Valid: true}}
			db.Save(&project)
			return err
		}

		// Process PSD
		if err := processor.Process(ctx); err != nil {
			log.Printf("Processing failed: %v\n", err)
			return err
		}

		log.Printf("Completed processing for project %d\n", projectID)
		return nil
	})
}

func (h *ProjectHandler) cleanupProjectFiles(project *models.Project) {
	// Delete PSD file
	if project.PsdPath != "" && fileExists(project.PsdPath) {
		os.RemoveAll(project.PsdPath)
	}

	// Delete export directory
	if project.ExportPath != "" && dirExists(project.ExportPath) {
		os.RemoveAll(project.ExportPath)
	}

	// Delete processed images
	// This will need public_path from config - for now skip
}

func fileExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && !info.IsDir()
}

func dirExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.IsDir()
}
