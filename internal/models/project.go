package models

import (
	"database/sql"
	"database/sql/driver"
	"encoding/json"
	"time"

	"gorm.io/gorm"
)

// StringArray is a custom type for storing string arrays in database
type StringArray []string

// Scan implements sql.Scanner
func (s *StringArray) Scan(value interface{}) error {
	if value == nil {
		*s = []string{}
		return nil
	}
	bytes, ok := value.([]byte)
	if !ok {
		return nil
	}
	return json.Unmarshal(bytes, s)
}

// Value implements driver.Valuer
func (s StringArray) Value() (driver.Value, error) {
	if len(s) == 0 {
		return "[]", nil
	}
	return json.Marshal(s)
}

// NullTime is a custom time type that handles NULL and invalid values
type NullTime struct {
	sql.NullTime
}

// Scan implements sql.Scanner
func (nt *NullTime) Scan(value interface{}) error {
	// Try to scan as NullTime first
	err := nt.NullTime.Scan(value)
	if err != nil {
		// If scan fails, treat as NULL
		nt.Valid = false
		nt.Time = time.Time{}
		return nil
	}
	return nil
}

// Value implements driver.Valuer
func (nt NullTime) Value() (driver.Value, error) {
	if !nt.Valid {
		return nil, nil
	}
	return nt.Time, nil
}

// MarshalJSON implements json.Marshaler
func (nt NullTime) MarshalJSON() ([]byte, error) {
	if !nt.Valid {
		return []byte("null"), nil
	}
	return json.Marshal(nt.Time.Unix())
}

// UnmarshalJSON implements json.Unmarshaler
func (nt *NullTime) UnmarshalJSON(data []byte) error {
	var timestamp int64
	if err := json.Unmarshal(data, &timestamp); err != nil {
		nt.Valid = false
		return nil
	}
	nt.Time = time.Unix(timestamp, 0)
	nt.Valid = true
	return nil
}

// Project represents a PSD processing project
type Project struct {
	gorm.Model
	Name                  string      `json:"name"`
	PsdPath               string      `json:"psd_path"`
	ExportPath            string      `json:"export_path"`
	Status                string      `json:"status" gorm:"default:pending"` // pending, processing, ready, error
	ExportScales          StringArray `json:"export_scales" gorm:"type:text"`
	Width                 int         `json:"width"`
	Height                int         `json:"height"`
	ProcessingMode        string      `json:"processing_mode"`
	ProcessingStartedAt   *NullTime   `json:"processing_started_at" gorm:"type:datetime"`
	ProcessingFinishedAt  *NullTime   `json:"processing_finished_at" gorm:"type:datetime"`
	Layers                []Layer     `json:"-" gorm:"foreignKey:ProjectID;constraint:OnDelete:CASCADE"`
}

// AsJSON returns project as JSON-compatible map with additional computed fields
func (p *Project) AsJSON() map[string]interface{} {
	result := map[string]interface{}{
		"id":                  p.ID,
		"name":                p.Name,
		"psd_path":            p.PsdPath,
		"export_path":         p.ExportPath,
		"status":              p.Status,
		"export_scales":       p.ExportScales,
		"width":               p.Width,
		"height":              p.Height,
		"processing_mode":     p.ProcessingMode,
		"created_at":          p.CreatedAt,
		"updated_at":          p.UpdatedAt,
		"file_size":           int64(0),
		"layers_count":        0,
		"processing_started_at": nil,
		"processing_finished_at": nil,
	}

	if p.ProcessingStartedAt != nil && p.ProcessingStartedAt.Valid {
		result["processing_started_at"] = p.ProcessingStartedAt.Time.Unix()
	}
	if p.ProcessingFinishedAt != nil && p.ProcessingFinishedAt.Valid {
		result["processing_finished_at"] = p.ProcessingFinishedAt.Time.Unix()
	}

	return result
}
