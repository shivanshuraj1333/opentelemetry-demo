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

log_info "Restarting infrastructure services..."

# Stop existing containers
docker compose down || true

# Remove any problematic containers
docker container prune -f || true

# Start infrastructure services
log_info "Starting infrastructure services..."
docker compose up -d

# Wait for services
log_info "Waiting for services to be ready..."
sleep 30

# Check status
log_info "Checking service status..."
docker compose ps

log_success "Infrastructure services restarted!"
echo
echo "🌐 Access the demo:"
echo "  Frontend: http://localhost:3000"
echo "  Jaeger UI: http://localhost:16686"
echo "  Grafana: http://localhost:3001 (admin/admin)"
echo "  Prometheus: http://localhost:9090"
echo "  Flagd UI: http://localhost:8080"
