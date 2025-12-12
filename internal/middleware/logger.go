package middleware

import (
	"log"
	"time"

	"github.com/gin-gonic/gin"
)

// Logger returns a logger middleware
func Logger() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path
		raw := c.Request.URL.RawQuery

		// Process request
		c.Next()

		// Calculate latency
		latency := time.Since(start)

		// Get status code
		statusCode := c.Writer.Status()

		// Build log message
		if raw != "" {
			path = path + "?" + raw
		}

		log.Printf("[%s] %s %d %v\n",
			c.Request.Method,
			path,
			statusCode,
			latency,
		)
	}
}
