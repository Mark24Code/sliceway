package database

import (
	"fmt"
	"log"
	"psd2img/internal/config"
	"psd2img/internal/models"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

var DB *gorm.DB

// Initialize initializes the database connection and runs migrations
func Initialize(cfg *config.Config) error {
	var err error

	// Configure GORM logger
	gormConfig := &gorm.Config{
		Logger: logger.Default.LogMode(logger.Info),
	}

	// Connect to SQLite database
	DB, err = gorm.Open(sqlite.Open(cfg.DBPath), gormConfig)
	if err != nil {
		return fmt.Errorf("failed to connect to database: %w", err)
	}

	// Run auto migrations
	err = DB.AutoMigrate(
		&models.Project{},
		&models.Layer{},
	)
	if err != nil {
		return fmt.Errorf("failed to run migrations: %w", err)
	}

	log.Println("Database initialized successfully")
	return nil
}

// GetDB returns the database instance
func GetDB() *gorm.DB {
	return DB
}
