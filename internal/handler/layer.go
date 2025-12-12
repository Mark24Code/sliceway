package handler

import (
	"net/http"
	"psd2img/internal/database"
	"psd2img/internal/models"

	"github.com/gin-gonic/gin"
)

type LayerHandler struct{}

func NewLayerHandler() *LayerHandler {
	return &LayerHandler{}
}

// ListLayers handles GET /api/projects/:id/layers
func (h *LayerHandler) ListLayers(c *gin.Context) {
	projectID := c.Param("id")
	layerType := c.Query("type")
	query := c.Query("q")

	db := database.GetDB()
	var layers []models.Layer

	q := db.Where("project_id = ?", projectID)

	if layerType != "" {
		q = q.Where("layer_type = ?", layerType)
	}

	if query != "" {
		q = q.Where("name LIKE ?", "%"+query+"%")
	}

	q.Find(&layers)

	c.JSON(http.StatusOK, layers)
}
