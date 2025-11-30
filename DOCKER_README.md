# Running Sliceway with Docker

This project is configured to run with Docker and Docker Compose.

## Prerequisites

- Docker
- Docker Compose

## Quick Start

1.  Run the start script:
    ```bash
    ./start_docker.sh
    ```

2.  Access the application:
    - Frontend: [http://localhost:5173](http://localhost:5173)
    - Backend API: [http://localhost:4567](http://localhost:4567)

## Configuration

The application uses the following volumes mapped to your local `data/` directory:

- `data/uploads`: Uploaded PSD files.
- `data/public`: Processed image assets.
- `data/db`: SQLite database file.
- `data/exports`: Exported files.

## Environment

- **Backend**: Ruby 3.3 (Alpine), Puma (5 threads), Production Mode.
- **Frontend**: Node.js 22 (Alpine), Vite Preview (Production Build).

## Stopping

To stop the application:
```bash
docker-compose down
```
