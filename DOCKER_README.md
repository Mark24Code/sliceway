# Running Sliceway with Docker

This project runs as a single container application. The frontend is built and served by the Ruby backend.

## Prerequisites

- Docker
- Docker Compose

## Quick Start

1.  Run the start script:
    ```bash
    ./start_docker.sh
    ```

2.  Access the application:
    - URL: [http://localhost:4567](http://localhost:4567)

## Configuration

The application uses the following volumes mapped to your local `data/` directory:

- `data/uploads`: Uploaded PSD files.
- `data/public`: Processed image assets (persisted).
- `data/db`: SQLite database file.
- `data/exports`: Exported files.

## Environment

- **Container**: Ruby 3.3 (Alpine) + Built Frontend Assets.
- **Server**: Puma (5 threads), Production Mode.

## Stopping

To stop the application:
```bash
docker-compose down
```
