#!/bin/bash

# OpenTelemetry Demo - Host Deployment Quick Start
# This script provides a complete setup for running the OpenTelemetry demo on a host with Coralogix

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

check_requirements() {
    log_info "Checking requirements..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check if Docker Compose is installed
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    log_success "Requirements check passed"
}

get_coralogix_key() {
    if [ -z "$CORALOGIX_PRIVATE_KEY" ]; then
        echo
        log_warning "CORALOGIX_PRIVATE_KEY environment variable not set"
        echo "Please enter your Coralogix private key:"
        read -s CORALOGIX_PRIVATE_KEY
        echo
    fi
    
    if [ -z "$CORALOGIX_PRIVATE_KEY" ]; then
        log_error "Coralogix private key is required"
        exit 1
    fi
}

install_coralogix() {
    log_info "Installing Coralogix Agent and Collector..."
    
    # Run the installation script
    ./install.sh
    
    # Set the private key
    echo "CORALOGIX_PRIVATE_KEY=$CORALOGIX_PRIVATE_KEY" > /etc/otelcol/coralogix.env
    chown otelcol:otelcol /etc/otelcol/coralogix.env
    chmod 600 /etc/otelcol/coralogix.env
    
    log_success "Coralogix installation completed"
}

start_coralogix_services() {
    log_info "Starting Coralogix services..."
    
    # Start services
    systemctl start coralogix-agent
    systemctl start coralogix-collector
    
    # Wait for services to start
    sleep 5
    
    # Check if services are running
    if systemctl is-active --quiet coralogix-agent && systemctl is-active --quiet coralogix-collector; then
        log_success "Coralogix services started successfully"
    else
        log_error "Failed to start Coralogix services"
        systemctl status coralogix-agent coralogix-collector
        exit 1
    fi
}

setup_demo_environment() {
    log_info "Setting up demo environment..."
    
    # Copy environment file
    cp env.host .env
    
    # Update with actual private key
    sed -i "s/your_coralogix_private_key_here/$CORALOGIX_PRIVATE_KEY/g" .env
    
    log_success "Demo environment configured"
}

start_infrastructure() {
    log_info "Starting infrastructure services..."
    
    # Start infrastructure services
    docker-compose -f docker-compose-host.yml up -d postgresql redis kafka zookeeper
    
    # Wait for services to be ready
    log_info "Waiting for infrastructure services to be ready..."
    sleep 30
    
    log_success "Infrastructure services started"
}

start_demo_services() {
    log_info "Starting demo services..."
    
    # Start demo services
    docker-compose -f docker-compose-host.yml up -d
    
    # Wait for services to be ready
    log_info "Waiting for demo services to be ready..."
    sleep 60
    
    log_success "Demo services started"
}

show_status() {
    log_info "Checking service status..."
    
    echo
    echo "=== Coralogix Services ==="
    systemctl status coralogix-agent --no-pager -l
    echo
    systemctl status coralogix-collector --no-pager -l
    
    echo
    echo "=== Demo Services ==="
    docker-compose -f docker-compose-host.yml ps
    
    echo
    echo "=== Service URLs ==="
    echo "Frontend: http://localhost:3000"
    echo "Load Generator: http://localhost:8089"
    echo "Coralogix Agent Health: http://localhost:13133"
    echo "Coralogix Collector Health: http://localhost:13133"
}

show_next_steps() {
    log_success "OpenTelemetry Demo with Coralogix is now running!"
    echo
    echo "Next steps:"
    echo "1. Access the demo frontend: http://localhost:3000"
    echo "2. Generate load: http://localhost:8089"
    echo "3. Check Coralogix platform for telemetry data"
    echo "4. View logs: docker-compose -f docker-compose-host.yml logs -f"
    echo "5. Monitor services: docker-compose -f docker-compose-host.yml ps"
    echo
    echo "To stop the demo:"
    echo "  docker-compose -f docker-compose-host.yml down"
    echo "  sudo systemctl stop coralogix-agent coralogix-collector"
    echo
    echo "Configuration files:"
    echo "  Agent: /etc/otelcol/agent.yaml"
    echo "  Collector: /etc/otelcol/collector.yaml"
    echo "  Environment: /etc/otelcol/coralogix.env"
}

main() {
    log_info "Starting OpenTelemetry Demo Host Deployment with Coralogix"
    echo
    
    check_requirements
    get_coralogix_key
    install_coralogix
    start_coralogix_services
    setup_demo_environment
    start_infrastructure
    start_demo_services
    show_status
    show_next_steps
}

# Run main function
main "$@"
