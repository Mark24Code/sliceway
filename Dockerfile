# Multi-stage build for Go application

# Stage 1: Build Frontend
FROM node:20-alpine AS frontend-builder
WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm ci --only=production
COPY frontend/ .
RUN npm run build

# Stage 2: Build Go Backend
FROM golang:1.25-alpine AS backend-builder

# Install build dependencies (CGO required for SQLite)
RUN apk add --no-cache git gcc musl-dev

WORKDIR /app

# Copy go mod files first for better caching
COPY go.mod go.sum ./

# Copy local psd library
COPY psd/ ./psd/

# Download dependencies
ENV GOPROXY=https://goproxy.cn,direct
RUN go mod download

# Copy source code
COPY cmd/ ./cmd/
COPY internal/ ./internal/

# Build the application with optimizations
RUN CGO_ENABLED=1 GOOS=linux go build \
    -ldflags="-s -w" \
    -o server ./cmd/server

# Stage 3: Runtime
FROM alpine:latest

# Install runtime dependencies
RUN apk add --no-cache \
    ca-certificates \
    sqlite \
    tzdata

WORKDIR /app

# Copy built binary
COPY --from=backend-builder /app/server .

# Copy frontend dist
COPY --from=frontend-builder /app/frontend/dist ./dist

# Copy VERSION file
COPY VERSION ./VERSION

# Create necessary directories
RUN mkdir -p /data/uploads \
    /data/public/processed \
    /data/db \
    /data/exports

# Environment variables
ENV PORT=4567
ENV UPLOADS_PATH=/data/uploads
ENV PUBLIC_PATH=/data/public
ENV DB_PATH=/data/db/production.sqlite3
ENV EXPORTS_PATH=/data/exports
ENV STATIC_PATH=/app/dist
ENV APP_ENV=production
ENV GIN_MODE=release

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:4567/api/version || exit 1

# Expose port
EXPOSE 4567

# Run as non-root user
RUN adduser -D -u 1000 appuser && \
    chown -R appuser:appuser /app /data
USER appuser

# Run the server
CMD ["/app/server"]
