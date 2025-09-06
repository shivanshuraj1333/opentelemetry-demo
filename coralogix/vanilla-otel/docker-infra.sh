#!/bin/bash

# OpenTelemetry Demo - Docker Infrastructure Management
# This script manages the Docker infrastructure services

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILE="docker-compose-infrastructure.yml"
PROJECT_NAME="otel-demo"

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

check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
}

get_compose_cmd() {
    if command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    elif docker compose version &> /dev/null; then
        echo "docker compose"
    else
        log_error "Neither docker-compose nor docker compose is available"
        exit 1
    fi
}

start_infrastructure() {
    log_info "Starting infrastructure services..."
    
    check_docker
    
    local compose_cmd=$(get_compose_cmd)
    
    # Start services
    $compose_cmd -f "$COMPOSE_FILE" -p "$PROJECT_NAME" up -d
    
    log_info "Waiting for services to be healthy..."
    sleep 10
    
    # Check service health
    local services=("postgres" "redis" "kafka" "jaeger" "otel-collector")
    for service in "${services[@]}"; do
        if $compose_cmd -f "$COMPOSE_FILE" -p "$PROJECT_NAME" ps "$service" | grep -q "healthy"; then
            log_success "$service is healthy"
        else
            log_warning "$service is not healthy yet"
        fi
    done
    
    log_success "Infrastructure services started"
    show_status
}

stop_infrastructure() {
    log_info "Stopping infrastructure services..."
    
    local compose_cmd=$(get_compose_cmd)
    $compose_cmd -f "$COMPOSE_FILE" -p "$PROJECT_NAME" down
    
    log_success "Infrastructure services stopped"
}

restart_infrastructure() {
    log_info "Restarting infrastructure services..."
    stop_infrastructure
    sleep 5
    start_infrastructure
}

show_status() {
    log_info "Infrastructure services status:"
    
    local compose_cmd=$(get_compose_cmd)
    $compose_cmd -f "$COMPOSE_FILE" -p "$PROJECT_NAME" ps
    
    echo
    log_info "Service URLs:"
    echo "  PostgreSQL: localhost:5432"
    echo "  Redis: localhost:6379"
    echo "  Kafka: localhost:9092"
    echo "  Jaeger UI: http://localhost:16686"
    echo "  OpenTelemetry Collector: http://localhost:13133"
}

show_logs() {
    local service=${1:-""}
    
    if [ -n "$service" ]; then
        log_info "Showing logs for $service..."
        local compose_cmd=$(get_compose_cmd)
        $compose_cmd -f "$COMPOSE_FILE" -p "$PROJECT_NAME" logs -f "$service"
    else
        log_info "Showing logs for all services..."
        local compose_cmd=$(get_compose_cmd)
        $compose_cmd -f "$COMPOSE_FILE" -p "$PROJECT_NAME" logs -f
    fi
}

clean_infrastructure() {
    log_info "Cleaning infrastructure services and data..."
    
    local compose_cmd=$(get_compose_cmd)
    $compose_cmd -f "$COMPOSE_FILE" -p "$PROJECT_NAME" down -v --remove-orphans
    
    # Remove volumes
    docker volume ls -q | grep otel-demo | xargs -r docker volume rm
    
    log_success "Infrastructure cleaned"
}

wait_for_services() {
    log_info "Waiting for all services to be ready..."
    
    local services=("postgres:5432" "redis:6379" "kafka:9092" "jaeger:16686" "otel-collector:13133")
    
    for service_port in "${services[@]}"; do
        local service=$(echo "$service_port" | cut -d: -f1)
        local port=$(echo "$service_port" | cut -d: -f2)
        
        log_info "Waiting for $service on port $port..."
        local max_attempts=30
        local attempt=1
        
        while [ $attempt -le $max_attempts ]; do
            if nc -z localhost "$port" 2>/dev/null; then
                log_success "$service is ready"
                break
            fi
            
            if [ $attempt -eq $max_attempts ]; then
                log_warning "$service is not ready after $max_attempts attempts"
            fi
            
            sleep 2
            ((attempt++))
        done
    done
}

main() {
    case "${1:-}" in
        start)
            start_infrastructure
            ;;
        stop)
            stop_infrastructure
            ;;
        restart)
            restart_infrastructure
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs "$2"
            ;;
        clean)
            clean_infrastructure
            ;;
        wait)
            wait_for_services
            ;;
        *)
            echo "Usage: $0 {start|stop|restart|status|logs|clean|wait}"
            echo
            echo "Commands:"
            echo "  start   - Start infrastructure services"
            echo "  stop    - Stop infrastructure services"
            echo "  restart - Restart infrastructure services"
            echo "  status  - Show service status"
            echo "  logs    - Show logs (optionally for specific service)"
            echo "  clean   - Stop and remove all data"
            echo "  wait    - Wait for all services to be ready"
            echo
            echo "Examples:"
            echo "  $0 start"
            echo "  $0 logs postgres"
            echo "  $0 status"
            exit 1
            ;;
    esac
}

main "$@"
