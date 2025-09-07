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

log_info "Restarting OpenTelemetry Collector with fixed configuration..."

# Stop collector
log_info "Stopping collector..."
docker stop vanilla-otel-otel-collector-1 || true
docker rm vanilla-otel-otel-collector-1 || true

# Start collector again
log_info "Starting collector..."
docker compose -f docker-compose-simple.yml up -d otel-collector

# Wait for collector
log_info "Waiting for collector to start..."
sleep 10

# Check collector logs
log_info "Checking collector logs..."
docker logs vanilla-otel-otel-collector-1

# Check status
log_info "Checking service status..."
docker compose -f docker-compose-simple.yml ps

log_success "OpenTelemetry Collector restarted with fixed configuration!"
