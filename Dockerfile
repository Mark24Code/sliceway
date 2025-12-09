# Stage 1: Build Frontend
FROM node:22-alpine AS frontend-builder
WORKDIR /app/frontend
COPY frontend/package.json frontend/package-lock.json ./
RUN npm install
COPY frontend/ .
# Build for production
RUN npm run build

# Stage 2: Setup Backend & Serve
FROM ruby:3.3-alpine

# Install dependencies
RUN apk add --no-cache \
    imagemagick \
    imagemagick-dev \
    sqlite-dev \
    build-base \
    tzdata \
    git \
    pkgconfig \
    procps \
    rust \
    cargo \
    musl-dev \
    libwebp \
    libwebp-dev \
    libwebp-tools

WORKDIR /app

# Copy Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Install gems
RUN bundle config set --local without 'development test' && \
    bundle install

# Copy application code
COPY . .

# Copy built frontend assets from builder stage
# Store in /app/dist separate from user data
COPY --from=frontend-builder /app/frontend/dist ./dist

# Create necessary directories for volume mounts
RUN mkdir -p /data/uploads \
    /data/public/processed \
    /data/db \
    /data/exports

# Expose port
EXPOSE 4567

# Environment variables
ENV RACK_ENV=production
ENV UPLOADS_PATH=/data/uploads
ENV PUBLIC_PATH=/data/public
ENV DB_PATH=/data/db/production.sqlite3
ENV EXPORTS_PATH=/data/exports
ENV STATIC_PATH=/app/dist
ENV RUBY_YJIT_ENABLE=1

# Start command
CMD ["sh", "-c", "bundle exec rake db:migrate && bundle exec puma -t 5:5 -p 4567 -e production"]
