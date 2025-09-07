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

log_info "Starting simplified infrastructure services..."

# Stop existing containers
docker compose -f docker-compose-simple.yml down || true

# Start infrastructure services
log_info "Starting infrastructure services..."
docker compose -f docker-compose-simple.yml up -d

# Wait for services
log_info "Waiting for services to be ready..."
sleep 30

# Check status
log_info "Checking service status..."
docker compose -f docker-compose-simple.yml ps

log_success "Infrastructure services started!"
echo
echo "🌐 Access the demo:"
echo "  Frontend: http://localhost:3000"
echo "  Jaeger UI: http://localhost:16686"
echo "  Grafana: http://localhost:3001 (admin/admin)"
echo "  Prometheus: http://localhost:9090"
echo
echo "📊 Infrastructure services running:"
echo "  PostgreSQL: localhost:5432"
echo "  Kafka: localhost:9092"
echo "  Zookeeper: localhost:2181"
echo "  Jaeger: localhost:16686"
echo "  OpenTelemetry Collector: localhost:4317/4318"
echo "  Prometheus: localhost:9090"
echo "  Grafana: localhost:3001"
