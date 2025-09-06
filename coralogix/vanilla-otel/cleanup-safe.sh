#!/bin/bash

# OpenTelemetry Demo - Safe Cleanup Script
# This script removes all traces of the OpenTelemetry demo installation
# (skips package cleanup to avoid dpkg issues)

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

cleanup_services() {
    log_info "Stopping and disabling all services..."
    
    # Stop all demo services
    systemctl stop oteldemo-frontend oteldemo-cart oteldemo-checkout oteldemo-currency oteldemo-payment oteldemo-product-catalog oteldemo-load-generator 2>/dev/null || true
    
    # Stop infrastructure services
    systemctl stop otel-collector jaeger kafka zookeeper 2>/dev/null || true
    
    # Disable all services
    systemctl disable oteldemo-frontend oteldemo-cart oteldemo-checkout oteldemo-currency oteldemo-payment oteldemo-product-catalog oteldemo-load-generator 2>/dev/null || true
    systemctl disable otel-collector jaeger kafka zookeeper 2>/dev/null || true
    
    log_success "Services stopped and disabled"
}

cleanup_files() {
    log_info "Removing all files and directories..."
    
    # Remove systemd service files
    rm -f /etc/systemd/system/oteldemo-*.service
    rm -f /etc/systemd/system/otel-collector.service
    rm -f /etc/systemd/system/jaeger.service
    rm -f /etc/systemd/system/kafka.service
    rm -f /etc/systemd/system/zookeeper.service
    
    # Remove installed binaries
    rm -f /usr/local/bin/otelcol-contrib
    rm -f /usr/local/bin/jaeger-all-in-one
    rm -f /usr/local/bin/kafka-server-start
    rm -f /usr/local/bin/kafka-topics
    rm -f /usr/local/bin/zookeeper-server-start
    
    # Remove directories
    rm -rf /opt/oteldemo
    rm -rf /opt/kafka
    rm -rf /etc/otelcol
    rm -rf /var/lib/jaeger
    rm -rf /var/lib/kafka-logs
    
    # Remove configuration files
    rm -f /etc/otelcol/otel-collector.yaml
    rm -f /etc/otelcol/env.vanilla
    
    log_success "Files and directories removed"
}

cleanup_users() {
    log_info "Removing service users and groups..."
    
    # Remove users
    userdel oteldemo 2>/dev/null || true
    userdel jaeger 2>/dev/null || true
    userdel kafka 2>/dev/null || true
    userdel zookeeper 2>/dev/null || true
    userdel otelcol 2>/dev/null || true
    
    # Remove groups
    groupdel oteldemo 2>/dev/null || true
    groupdel jaeger 2>/dev/null || true
    groupdel kafka 2>/dev/null || true
    groupdel zookeeper 2>/dev/null || true
    groupdel otelcol 2>/dev/null || true
    
    log_success "Users and groups removed"
}

reset_configurations() {
    log_info "Resetting system configurations..."
    
    # Reset Redis configuration
    if [ -f "/etc/redis/redis.conf" ]; then
        sed -i 's/^bind 127.0.0.1/# bind 127.0.0.1/' /etc/redis/redis.conf
        sed -i 's/^requirepass otel/# requirepass foobared/' /etc/redis/redis.conf
        log_success "Redis configuration reset"
    fi
    
    # Reset PostgreSQL configuration
    if [ -f "/etc/postgresql/*/main/pg_hba.conf" ]; then
        sed -i '/host all all 0.0.0.0\/0 md5/d' /etc/postgresql/*/main/pg_hba.conf 2>/dev/null || true
        log_success "PostgreSQL configuration reset"
    fi
    
    # Reload systemd
    systemctl daemon-reload
    
    log_success "System configurations reset"
}

cleanup_logs() {
    log_info "Cleaning up logs..."
    
    # Remove any remaining log files
    rm -f /tmp/otel-demo-*.log
    rm -f /tmp/otel-demo-test-*.txt
    
    log_success "Logs cleaned up"
}

main() {
    log_info "Starting safe cleanup of OpenTelemetry Demo installation"
    log_warning "Skipping package cleanup to avoid dpkg issues"
    
    check_root
    
    cleanup_services
    cleanup_files
    cleanup_users
    reset_configurations
    cleanup_logs
    
    log_success "Safe cleanup finished!"
    log_info "The system is now clean and ready for a fresh installation"
    log_info "You can now run: sudo ./install.sh"
    log_warning "Note: You may need to fix dpkg issues manually if they persist"
}

main "$@"
