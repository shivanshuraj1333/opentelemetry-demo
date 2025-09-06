#!/bin/bash

# OpenTelemetry Demo - VM Fix Script
# This script fixes common issues on Ubuntu VM

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

cleanup_previous() {
    log_info "Cleaning up previous installation..."
    
    # Stop all services
    systemctl stop oteldemo-frontend oteldemo-cart oteldemo-checkout oteldemo-currency oteldemo-payment oteldemo-product-catalog oteldemo-load-generator 2>/dev/null || true
    systemctl stop otel-collector jaeger kafka zookeeper 2>/dev/null || true
    
    # Disable services
    systemctl disable oteldemo-frontend oteldemo-cart oteldemo-checkout oteldemo-currency oteldemo-payment oteldemo-product-catalog oteldemo-load-generator 2>/dev/null || true
    systemctl disable otel-collector jaeger kafka zookeeper 2>/dev/null || true
    
    # Remove service files
    rm -f /etc/systemd/system/oteldemo-*.service
    rm -f /etc/systemd/system/otel-collector.service
    rm -f /etc/systemd/system/jaeger.service
    rm -f /etc/systemd/system/kafka.service
    rm -f /etc/systemd/system/zookeeper.service
    
    # Remove directories
    rm -rf /opt/oteldemo
    rm -rf /opt/kafka
    rm -rf /etc/otelcol
    rm -rf /var/lib/jaeger
    rm -rf /var/lib/kafka-logs
    
    # Remove users
    userdel oteldemo 2>/dev/null || true
    userdel jaeger 2>/dev/null || true
    userdel kafka 2>/dev/null || true
    userdel zookeeper 2>/dev/null || true
    userdel otelcol 2>/dev/null || true
    
    # Reload systemd
    systemctl daemon-reload
    
    log_success "Cleanup completed"
}

fix_nodejs() {
    log_info "Fixing Node.js version..."
    
    # Remove old Node.js
    apt-get remove -y nodejs npm || true
    
    # Install Node.js 20+ from NodeSource
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
    
    log_success "Node.js updated to version $(node --version)"
}

fix_redis() {
    log_info "Fixing Redis configuration..."
    
    # Stop Redis if running
    systemctl stop redis-server || true
    
    # Configure Redis
    if [ -f "/etc/redis/redis.conf" ]; then
        sed -i 's/^# bind 127.0.0.1/bind 127.0.0.1/' /etc/redis/redis.conf
        sed -i 's/^# requirepass foobared/requirepass otel/' /etc/redis/redis.conf
        log_success "Redis configured"
    fi
    
    # Start Redis
    systemctl start redis-server
    systemctl enable redis-server
    
    log_success "Redis fixed and started"
}

fix_users() {
    log_info "Creating missing users..."
    
    # Create oteldemo user if it doesn't exist
    if ! id "oteldemo" &>/dev/null; then
        useradd --system --no-create-home --shell /bin/false "oteldemo"
        log_success "Created user: oteldemo"
    else
        log_info "User oteldemo already exists"
    fi
    
    # Create other users
    for user in jaeger kafka zookeeper; do
        if ! id "$user" &>/dev/null; then
            useradd --system --no-create-home --shell /bin/false "$user"
            log_success "Created user: $user"
        else
            log_info "User $user already exists"
        fi
    done
}

fix_services() {
    log_info "Fixing systemd services..."
    
    # Reload systemd
    systemctl daemon-reload
    
    # Enable services
    systemctl enable postgresql redis-server otel-collector jaeger kafka zookeeper
    
    # Enable demo services
    for service in oteldemo-frontend oteldemo-cart oteldemo-checkout oteldemo-currency oteldemo-payment oteldemo-product-catalog oteldemo-load-generator; do
        systemctl enable "$service" || true
    done
    
    log_success "Services enabled"
}

start_infrastructure() {
    log_info "Starting infrastructure services..."
    
    # Start in order
    systemctl start postgresql
    sleep 2
    systemctl start redis-server
    sleep 2
    systemctl start otel-collector
    sleep 2
    systemctl start jaeger
    sleep 2
    systemctl start kafka
    sleep 2
    systemctl start zookeeper
    
    log_success "Infrastructure services started"
}

start_demo_services() {
    log_info "Starting demo services..."
    
    # Start demo services
    for service in oteldemo-frontend oteldemo-cart oteldemo-checkout oteldemo-currency oteldemo-payment oteldemo-product-catalog oteldemo-load-generator; do
        systemctl start "$service" || log_warning "Failed to start $service"
    done
    
    log_success "Demo services started"
}

check_status() {
    log_info "Checking service status..."
    
    echo "Infrastructure services:"
    systemctl is-active postgresql redis-server otel-collector jaeger kafka zookeeper || true
    
    echo "Demo services:"
    systemctl is-active oteldemo-frontend oteldemo-cart oteldemo-checkout oteldemo-currency oteldemo-payment oteldemo-product-catalog oteldemo-load-generator || true
}

main() {
    log_info "Starting VM fix process..."
    
    check_root
    cleanup_previous
    
    fix_nodejs
    fix_redis
    fix_users
    fix_services
    start_infrastructure
    start_demo_services
    check_status
    
    log_success "VM fix completed!"
    log_info "Access the demo at: http://localhost:3000"
}

main "$@"
