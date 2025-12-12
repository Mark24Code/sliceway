package models

import (
	"database/sql/driver"
	"encoding/json"

	"gorm.io/gorm"
)

// Metadata is a custom type for storing JSON metadata
type Metadata map[string]interface{}

// Scan implements sql.Scanner
func (m *Metadata) Scan(value interface{}) error {
	if value == nil {
		*m = make(map[string]interface{})
		return nil
	}
	bytes, ok := value.([]byte)
	if !ok {
		return nil
	}
	return json.Unmarshal(bytes, m)
}

// Value implements driver.Valuer
func (m Metadata) Value() (driver.Value, error) {
	if len(m) == 0 {
		return "{}", nil
	}
	return json.Marshal(m)
}

// Layer represents a layer, slice, group, or text element from PSD
type Layer struct {
	gorm.Model
	ProjectID  uint     `json:"project_id" gorm:"index"`
	ResourceID string   `json:"resource_id"`
	Name       string   `json:"name"`
	LayerType  string   `json:"layer_type" gorm:"index"` // slice, layer, group, text
	X          int      `json:"x"`
	Y          int      `json:"y"`
	Width      int      `json:"width"`
	Height     int      `json:"height"`
	Content    string   `json:"content"`    // For text layers
	ImagePath  string   `json:"image_path"` // Relative path
	Metadata   Metadata `json:"metadata" gorm:"type:text"`
	ParentID   *uint    `json:"parent_id"`
	Hidden     bool     `json:"hidden" gorm:"default:false"`
}
