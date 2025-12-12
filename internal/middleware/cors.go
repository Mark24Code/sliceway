package middleware

import (
	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

// CORS returns a CORS middleware with permissive settings
func CORS() gin.HandlerFunc {
	config := cors.Config{
		AllowOrigins:     []string{"*"},
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"*"},
		ExposeHeaders:    []string{"Location", "Link"},
		AllowCredentials: false,
	}
	return cors.New(config)
}
