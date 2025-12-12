package config

import (
	"os"
	"path/filepath"
)

// Config holds application configuration
type Config struct {
	ServerPort  string
	UploadsPath string
	PublicPath  string
	DBPath      string
	ExportsPath string
	StaticPath  string
	Environment string
}

// Load loads configuration from environment variables
func Load() *Config {
	cfg := &Config{
		ServerPort:  getEnv("PORT", "4567"),
		UploadsPath: getEnv("UPLOADS_PATH", "uploads"),
		PublicPath:  getEnv("PUBLIC_PATH", "public"),
		DBPath:      getEnv("DB_PATH", "db/development.sqlite3"),
		ExportsPath: getEnv("EXPORTS_PATH", "exports"),
		StaticPath:  getEnv("STATIC_PATH", "dist"),
		Environment: getEnv("APP_ENV", "development"),
	}

	// Create necessary directories
	dirs := []string{
		cfg.UploadsPath,
		cfg.PublicPath,
		filepath.Join(cfg.PublicPath, "processed"),
		cfg.ExportsPath,
		filepath.Dir(cfg.DBPath),
	}

	for _, dir := range dirs {
		os.MkdirAll(dir, 0755)
	}

	return cfg
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
