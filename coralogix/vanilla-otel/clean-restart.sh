#!/bin/bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

log_info "Cleaning up and restarting infrastructure..."

# Stop all containers
log_info "Stopping all containers..."
docker compose -f docker-compose-simple.yml down || true
docker compose down || true

# Remove any containers using the ports
log_info "Removing containers using conflicting ports..."
docker ps -a --filter "publish=14250" --format "{{.ID}}" | xargs -r docker rm -f || true
docker ps -a --filter "publish=16686" --format "{{.ID}}" | xargs -r docker rm -f || true
docker ps -a --filter "publish=5432" --format "{{.ID}}" | xargs -r docker rm -f || true
docker ps -a --filter "publish=9092" --format "{{.ID}}" | xargs -r docker rm -f || true
docker ps -a --filter "publish=2181" --format "{{.ID}}" | xargs -r docker rm -f || true
docker ps -a --filter "publish=4317" --format "{{.ID}}" | xargs -r docker rm -f || true
docker ps -a --filter "publish=4318" --format "{{.ID}}" | xargs -r docker rm -f || true
docker ps -a --filter "publish=9090" --format "{{.ID}}" | xargs -r docker rm -f || true
docker ps -a --filter "publish=3001" --format "{{.ID}}" | xargs -r docker rm -f || true

# Clean up networks
log_info "Cleaning up networks..."
docker network prune -f || true

# Check what's using the ports
log_info "Checking port usage..."
netstat -tulpn | grep -E ":(14250|16686|5432|9092|2181|4317|4318|9090|3001)" || true

# Start infrastructure services
log_info "Starting infrastructure services..."
docker compose -f docker-compose-simple.yml up -d

# Wait for services
log_info "Waiting for services to be ready..."
sleep 30

# Check status
log_info "Checking service status..."
docker compose -f docker-compose-simple.yml ps

log_success "Infrastructure services restarted!"
echo
echo "🌐 Access the demo:"
echo "  Frontend: http://localhost:3000"
echo "  Jaeger UI: http://localhost:16686"
echo "  Grafana: http://localhost:3001 (admin/admin)"
echo "  Prometheus: http://localhost:9090"
