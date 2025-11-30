# User requested ruby 3.4.7, but it's not available yet. Using latest stable 3.3-alpine.
FROM ruby:3.3-alpine

# Install dependencies
# imagemagick: for RMagick
# sqlite-dev: for sqlite3 gem
# build-base: for compiling native extensions
# tzdata: for timezones
# git: for bundler if needed
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

# Expose port
EXPOSE 4567

# Environment variables
ENV RACK_ENV=production

# Start command
# Run with Puma, 5 threads min/max, port 4567, production environment
CMD ["bundle", "exec", "puma", "-t", "5:5", "-p", "4567", "-e", "production"]
