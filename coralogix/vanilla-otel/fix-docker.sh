#!/bin/bash

# Quick fix for Docker infrastructure issues

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

main() {
    log_info "Fixing Docker infrastructure issues..."
    
    # Detect compose command
    if command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        COMPOSE_CMD="docker compose"
    fi
    
    # Stop any running containers
    log_info "Stopping existing containers..."
    $COMPOSE_CMD -f docker-compose-infrastructure.yml down 2>/dev/null || true
    
    # Remove any problematic containers
    log_info "Cleaning up containers..."
    docker container rm -f otel-zookeeper otel-kafka otel-postgres otel-redis otel-jaeger otel-collector 2>/dev/null || true
    
    # Start fresh
    log_info "Starting infrastructure services..."
    $COMPOSE_CMD -f docker-compose-infrastructure.yml up -d
    
    # Wait a bit
    sleep 10
    
    # Check status
    log_info "Checking service status..."
    $COMPOSE_CMD -f docker-compose-infrastructure.yml ps
    
    log_success "Fix completed!"
    log_info "Check status with: ./docker-infra.sh status"
}

main "$@"
