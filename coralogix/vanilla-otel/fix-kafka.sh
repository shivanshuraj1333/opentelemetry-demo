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

log_info "Fixing Kafka..."

# Stop Kafka container
log_info "Stopping Kafka container..."
docker stop vanilla-otel-kafka-1 || true
docker rm vanilla-otel-kafka-1 || true

# Remove Kafka volume to start fresh
log_info "Removing Kafka volume..."
docker volume rm vanilla-otel_kafka_data || true

# Start Kafka again
log_info "Starting Kafka..."
docker compose -f docker-compose-simple.yml up -d kafka

# Wait for Kafka
log_info "Waiting for Kafka to start..."
sleep 30

# Check Kafka logs
log_info "Checking Kafka logs..."
docker logs vanilla-otel-kafka-1

# Check status
log_info "Checking service status..."
docker compose -f docker-compose-simple.yml ps

log_success "Kafka should be fixed now!"
