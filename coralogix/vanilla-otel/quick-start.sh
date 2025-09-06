#!/bin/bash

# OpenTelemetry Demo - Quick Start Script
# This script provides a quick way to start the demo services

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
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

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

start_infrastructure() {
    log_info "Starting infrastructure services (Docker)..."
    
    if [ -f "./docker-infra.sh" ]; then
        ./docker-infra.sh start
        log_success "Docker infrastructure started"
    else
        log_error "docker-infra.sh not found"
        exit 1
    fi
}

start_demo_services() {
    log_info "Starting demo services..."
    
    # Start core services
    systemctl start oteldemo-product-catalog
    systemctl start oteldemo-currency
    systemctl start oteldemo-payment
    systemctl start oteldemo-cart
    systemctl start oteldemo-checkout
    
    # Wait for core services to be ready
    sleep 10
    
    # Start frontend
    systemctl start oteldemo-frontend
    log_success "Frontend started"
    
    # Start load generator
    systemctl start oteldemo-load-generator
    log_success "Load Generator started"
}

check_services() {
    log_info "Checking service status..."
    
    # Check infrastructure services
    echo "Infrastructure Services:"
    systemctl is-active postgresql redis-server kafka zookeeper otel-collector jaeger
    
    echo
    echo "Demo Services:"
    systemctl is-active oteldemo-frontend oteldemo-cart oteldemo-checkout \
        oteldemo-currency oteldemo-payment oteldemo-product-catalog \
        oteldemo-load-generator
}

show_access_info() {
    log_success "OpenTelemetry Demo is running!"
    echo
    echo "Access URLs:"
    echo "  Frontend:        http://localhost:3000"
    echo "  Jaeger UI:       http://localhost:16686"
    echo "  Load Generator:  http://localhost:8089"
    echo "  Collector Health: http://localhost:13133"
    echo
    echo "Service Ports:"
    echo "  Frontend:        3000"
    echo "  Cart:            8081"
    echo "  Checkout:        8082"
    echo "  Currency:        8083"
    echo "  Payment:         8085"
    echo "  Product Catalog: 8086"
    echo "  Load Generator:  8089"
    echo
    echo "To view logs:"
    echo "  sudo journalctl -u otel-collector -f"
    echo "  sudo journalctl -u oteldemo-frontend -f"
    echo "  sudo journalctl -u 'oteldemo-*' -f"
    echo
    echo "To stop services:"
    echo "  sudo systemctl stop oteldemo-*"
    echo "  sudo systemctl stop otel-collector jaeger kafka zookeeper redis-server postgresql"
}

stop_all_services() {
    log_info "Stopping all services..."
    
    # Stop demo services
    systemctl stop oteldemo-* || true
    
    # Stop infrastructure services
    systemctl stop otel-collector jaeger kafka zookeeper redis-server postgresql || true
    
    log_success "All services stopped"
}

show_usage() {
    echo "Usage: $0 [command]"
    echo
    echo "Commands:"
    echo "  start     - Start all services (default)"
    echo "  stop      - Stop all services"
    echo "  restart   - Restart all services"
    echo "  status    - Show service status"
    echo "  logs      - Show logs for all services"
    echo "  help      - Show this help message"
    echo
}

show_logs() {
    log_info "Showing logs for all services..."
    echo "Press Ctrl+C to exit"
    journalctl -u "oteldemo-*" -u "otel-collector" -u "jaeger" -f
}

main() {
    check_root
    
    case "${1:-start}" in
        "start")
            start_infrastructure
            start_demo_services
            check_services
            show_access_info
            ;;
        "stop")
            stop_all_services
            ;;
        "restart")
            stop_all_services
            sleep 5
            start_infrastructure
            start_demo_services
            check_services
            show_access_info
            ;;
        "status")
            check_services
            ;;
        "logs")
            show_logs
            ;;
        "help")
            show_usage
            ;;
        *)
            log_error "Unknown command: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
