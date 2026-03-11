---
name: ops-run-local
description: "Manage the local Docker Compose development environment. Supports start, stop, restart, and status operations."
allowed-tools: ["Bash", "Read"]
---

# Manage Local Development Environment

Manage the local Docker Compose stack for the Railsstarter Rails application.

**Action**: `$ARGUMENTS` (expected: `start`, `stop`, `restart`, or `status`; default: `start`)

## Workflow

### Prerequisites (all actions)

1. **Verify Docker is running**:
   ```bash
   docker info > /dev/null 2>&1
   ```
   If not running, inform the user to start Docker Desktop.

2. **Verify `.env` file exists**:
   ```bash
   test -f .env
   ```
   If not, inform the user to copy `env.sample` to `.env`.

### Action: `start`

1. Build and start all services in the background:
   ```bash
   docker compose up --build -d
   ```

2. Wait for the db health check to pass:
   ```bash
   docker compose ps
   ```

3. Run a health check:
   ```bash
   curl -sf http://localhost:3000/up
   ```

4. Report the result: services running, port 3000 available

### Action: `stop`

1. Stop all services:
   ```bash
   docker compose down
   ```

2. Confirm services are stopped:
   ```bash
   docker compose ps
   ```

### Action: `restart`

1. Stop all services:
   ```bash
   docker compose down
   ```

2. Build and start all services:
   ```bash
   docker compose up --build -d
   ```

3. Health check:
   ```bash
   curl -sf http://localhost:3000/up
   ```

### Action: `status`

1. Show running containers:
   ```bash
   docker compose ps
   ```

2. Run health checks:
   ```bash
   curl -sf http://localhost:3000/up && echo "Web: healthy" || echo "Web: unhealthy"
   ```

3. Show recent logs (last 10 lines per service):
   ```bash
   docker compose logs --tail=10 web worker
   ```

## Execution

Run the specified action now.
