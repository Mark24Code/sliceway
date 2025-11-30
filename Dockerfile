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
    pkgconfig

WORKDIR /app

# Copy Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Install gems
RUN bundle config set --local without 'development test' && \
    bundle install

# Copy application code
COPY . .

# Copy built frontend assets from builder stage
# We copy them to 'dist' so we can separate them from the mutable 'public' folder
COPY --from=frontend-builder /app/frontend/dist ./dist

# Create public directory for processed images
RUN mkdir -p public

# Expose port
EXPOSE 4567

# Environment variables
ENV RACK_ENV=production
ENV PUBLIC_PATH=/app/public
ENV STATIC_PATH=/app/dist

# Start command
# Run with Puma, 5 threads min/max, port 4567, production environment
CMD ["bundle", "exec", "puma", "-t", "5:5", "-p", "4567", "-e", "production"]
