#!/bin/bash

# OpenTelemetry Demo - Vanilla Host Installation Script
# This script installs and configures the OpenTelemetry demo services on a host system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
OTELCOL_VERSION="0.131.1"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/otelcol"
DATA_DIR="/var/lib/otelcol"
SERVICE_USER="oteldemo"
SERVICE_GROUP="oteldemo"
OTEL_USER="otelcol"
OTEL_GROUP="otelcol"

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

cleanup_previous_installation() {
    log_info "Cleaning up previous installation..."
    
    # Stop all services
    log_info "Stopping all services..."
    systemctl stop oteldemo-frontend oteldemo-cart oteldemo-checkout oteldemo-currency oteldemo-payment oteldemo-product-catalog oteldemo-load-generator 2>/dev/null || true
    systemctl stop otel-collector jaeger kafka zookeeper 2>/dev/null || true
    systemctl stop redis-server postgresql 2>/dev/null || true
    
    # Disable services
    log_info "Disabling services..."
    systemctl disable oteldemo-frontend oteldemo-cart oteldemo-checkout oteldemo-currency oteldemo-payment oteldemo-product-catalog oteldemo-load-generator 2>/dev/null || true
    systemctl disable otel-collector jaeger kafka zookeeper 2>/dev/null || true
    
    # Remove systemd service files
    log_info "Removing systemd service files..."
    rm -f /etc/systemd/system/oteldemo-*.service
    rm -f /etc/systemd/system/otel-collector.service
    rm -f /etc/systemd/system/jaeger.service
    rm -f /etc/systemd/system/kafka.service
    rm -f /etc/systemd/system/zookeeper.service
    
    # Remove installed binaries
    log_info "Removing installed binaries..."
    rm -f /usr/local/bin/otelcol-contrib
    rm -f /usr/local/bin/jaeger-all-in-one
    rm -f /usr/local/bin/kafka-server-start
    rm -f /usr/local/bin/kafka-topics
    rm -f /usr/local/bin/zookeeper-server-start
    
    # Remove directories
    log_info "Removing directories..."
    rm -rf /opt/oteldemo
    rm -rf /opt/kafka
    rm -rf /etc/otelcol
    rm -rf /var/lib/jaeger
    rm -rf /var/lib/kafka-logs
    
    # Remove users (but keep system users like postgres, redis)
    log_info "Removing service users..."
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
    
    # Clean up package cache (skip if dpkg has issues)
    log_info "Cleaning package cache..."
    if dpkg --configure -a 2>/dev/null; then
        apt-get clean
        apt-get autoremove -y
        log_success "Package cache cleaned"
    else
        log_warning "Skipping package cleanup due to dpkg issues"
    fi
    
    # Reload systemd
    systemctl daemon-reload
    
    # Reset Redis configuration
    log_info "Resetting Redis configuration..."
    if [ -f "/etc/redis/redis.conf" ]; then
        sed -i 's/^bind 127.0.0.1/# bind 127.0.0.1/' /etc/redis/redis.conf
        sed -i 's/^requirepass otel/# requirepass foobared/' /etc/redis/redis.conf
    fi
    
    # Reset PostgreSQL configuration
    log_info "Resetting PostgreSQL configuration..."
    if [ -f "/etc/postgresql/*/main/pg_hba.conf" ]; then
        sed -i '/host all all 0.0.0.0\/0 md5/d' /etc/postgresql/*/main/pg_hba.conf 2>/dev/null || true
    fi
    
    log_success "Cleanup completed"
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    else
        log_error "Cannot detect OS version"
        exit 1
    fi
}

install_dependencies() {
    log_info "Installing dependencies..."
    
    # Fix dpkg issues first
    log_info "Checking and fixing dpkg issues..."
    if ! dpkg --configure -a 2>/dev/null; then
        log_warning "dpkg has issues, attempting to fix..."
        apt-get update --fix-missing
        apt-get install -f -y
        dpkg --configure -a || log_warning "dpkg issues persist, continuing anyway"
    fi
    
    case $OS in
        "Ubuntu"|"Debian")
            log_info "Updating package lists..."
            apt-get update
            
            log_info "Installing system packages..."
            apt-get install -y wget curl unzip systemd \
                python3 python3-pip python3-venv \
                dotnet-sdk-8.0 golang-go php-cli php-curl php-json \
                build-essential cmake pkg-config libssl-dev \
                docker.io docker-compose-plugin netcat-openbsd || log_error "Some packages failed to install"
            
            log_info "Installing Node.js 20+ from NodeSource..."
            curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
            apt-get install -y nodejs || log_error "Node.js installation failed"
            ;;
        "CentOS"|"Red Hat Enterprise Linux"|"Rocky Linux"|"AlmaLinux")
            yum update -y
            yum install -y wget curl unzip systemd postgresql-server postgresql-contrib redis \
                java-11-openjdk-devel nodejs npm python3 python3-pip \
                dotnet-sdk-6.0 golang php-cli php-json \
                gcc gcc-c++ make cmake openssl-devel \
                confluent-kafka confluent-zookeeper
            ;;
        "Amazon Linux")
            yum update -y
            yum install -y wget curl unzip systemd postgresql-server postgresql-contrib redis \
                java-11-openjdk-devel nodejs npm python3 python3-pip \
                golang php-cli php-json \
                gcc gcc-c++ make cmake openssl-devel
            ;;
        *)
            log_warning "Unsupported OS: $OS. Please install dependencies manually."
            ;;
    esac
}

setup_docker() {
    log_info "Setting up Docker infrastructure..."
    
    # Start Docker service
    systemctl start docker
    systemctl enable docker
    
    # Add current user to docker group (if not root)
    if [ "$(id -u)" -ne 0 ]; then
        usermod -aG docker "$(logname)" 2>/dev/null || true
    fi
    
    # Start infrastructure services
    if [ -f "./docker-infra.sh" ]; then
        chmod +x ./docker-infra.sh
        ./docker-infra.sh start
        log_success "Docker infrastructure started"
    else
        log_error "docker-infra.sh not found"
        exit 1
    fi
}


create_users() {
    log_info "Creating service users and groups..."
    
    # Create otelcol user
    if ! id "$OTEL_USER" &>/dev/null; then
        useradd --system --no-create-home --shell /bin/false "$OTEL_USER"
        log_success "Created user: $OTEL_USER"
    else
        log_info "User $OTEL_USER already exists"
    fi
    
    # Create oteldemo user
    if ! id "$SERVICE_USER" &>/dev/null; then
        useradd --system --no-create-home --shell /bin/false "$SERVICE_USER"
        log_success "Created user: $SERVICE_USER"
    else
        log_info "User $SERVICE_USER already exists"
    fi
    
    # Note: Infrastructure services (PostgreSQL, Redis, Kafka, Zookeeper, Jaeger, OpenTelemetry Collector)
    # are now running in Docker containers, so we don't need to create users for them
}

create_directories() {
    log_info "Creating directories..."
    
    # Create directories for demo services only
    mkdir -p "/opt/oteldemo"
    
    # Set ownership
    chown -R "$SERVICE_USER:$SERVICE_GROUP" "/opt/oteldemo"
    
    log_success "Created directories"
}

install_configs() {
    log_info "Installing configuration files..."
    
    # Copy collector configuration
    cp otel-collector.yaml "$CONFIG_DIR/"
    
    # Set permissions
    chown -R "$OTEL_USER:$OTEL_GROUP" "$CONFIG_DIR"
    chmod 644 "$CONFIG_DIR"/*.yaml
    
    log_success "Configuration files installed"
}

install_systemd_services() {
    log_info "Installing systemd services for demo services..."
    
    # Copy only demo service files (infrastructure runs in Docker)
    cp services/oteldemo-*.service /etc/systemd/system/
    
    # Reload systemd
    systemctl daemon-reload
    
    log_success "Demo systemd services installed"
}

setup_database() {
    log_info "Setting up PostgreSQL database (running in Docker)..."
    
    # Wait for PostgreSQL container to be ready
    log_info "Waiting for PostgreSQL to be ready..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if nc -z localhost 5432 2>/dev/null; then
            log_success "PostgreSQL is ready"
            break
        fi
        
        if [ $attempt -eq $max_attempts ]; then
            log_warning "PostgreSQL is not ready after $max_attempts attempts"
            return 1
        fi
        
        sleep 2
        ((attempt++))
    done
    
    # Database and user are already created by Docker init script
    log_success "Database setup completed (handled by Docker)"
}

setup_demo_services() {
    log_info "Setting up demo services..."
    
    # Run the setup-demo.sh script
    if [ -f "./setup-demo.sh" ]; then
        chmod +x ./setup-demo.sh
        ./setup-demo.sh
        log_success "Demo services setup completed"
    else
        log_warning "setup-demo.sh not found, skipping demo services setup"
    fi
}

configure_services() {
    log_info "Configuring services..."
    
    # Configure Redis
    if [ -f "/etc/redis/redis.conf" ]; then
        sed -i 's/^# bind 127.0.0.1/bind 127.0.0.1/' /etc/redis/redis.conf
        sed -i 's/^# requirepass foobared/requirepass otel/' /etc/redis/redis.conf
        log_success "Redis configured"
    fi
    
    # Configure PostgreSQL
    if [ -f "/etc/postgresql/*/main/postgresql.conf" ]; then
        # Enable connections
        echo "host all all 0.0.0.0/0 md5" >> /etc/postgresql/*/main/pg_hba.conf
        log_success "PostgreSQL configured"
    fi
}

start_services() {
    log_info "Starting demo services..."
    
    # Infrastructure services are already running in Docker
    log_info "Infrastructure services are running in Docker containers"
    
    # Start demo services with error handling
    for service in oteldemo-frontend oteldemo-cart oteldemo-checkout oteldemo-currency oteldemo-payment oteldemo-product-catalog oteldemo-load-generator; do
        systemctl start "$service" || log_warning "$service failed to start"
        sleep 1
    done
    
    log_success "Demo services started"
    log_info "Check service status with: sudo ./quick-start.sh status"
    log_info "Check Docker infrastructure with: ./docker-infra.sh status"
}

check_installation() {
    log_info "Checking installation status..."
    
    # Check Docker infrastructure services
    log_info "Checking Docker infrastructure services..."
    if [ -f "./docker-infra.sh" ]; then
        ./docker-infra.sh status
    else
        log_warning "docker-infra.sh not found, cannot check Docker services"
    fi
    
    # Check demo services
    local demo_failed=()
    for service in oteldemo-frontend oteldemo-cart oteldemo-checkout oteldemo-currency oteldemo-payment oteldemo-product-catalog oteldemo-load-generator; do
        if ! systemctl is-active --quiet "$service"; then
            demo_failed+=("$service")
        fi
    done
    
    if [ ${#demo_failed[@]} -gt 0 ]; then
        log_warning "Some demo services failed to start: ${demo_failed[*]}"
        log_info "You can try to start them manually:"
        for service in "${demo_failed[@]}"; do
            log_info "  sudo systemctl start $service"
        done
    else
        log_success "All demo services are running"
    fi
}

enable_services() {
    log_info "Enabling demo services..."
    
    # Infrastructure services are managed by Docker, no need to enable them
    log_info "Infrastructure services are managed by Docker"
    
    # Enable demo services
    systemctl enable oteldemo-frontend oteldemo-cart oteldemo-checkout \
        oteldemo-currency oteldemo-payment oteldemo-product-catalog \
        oteldemo-load-generator
    
    log_success "Demo services enabled"
}

show_next_steps() {
    log_success "Installation completed!"
    echo
    echo "Next steps:"
    echo "1. Setup the demo services:"
    echo "   sudo ./setup-demo.sh"
    echo "2. Start infrastructure services:"
    echo "   sudo systemctl start postgresql redis-server otel-collector jaeger"
    echo "3. Start demo services:"
    echo "   sudo systemctl start oteldemo-frontend oteldemo-cart oteldemo-checkout"
    echo "4. Access the demo:"
    echo "   Frontend: http://localhost:3000"
    echo "   Jaeger UI: http://localhost:16686"
    echo "   Load Generator: http://localhost:8089"
    echo
    echo "Configuration files:"
    echo "  Collector: $CONFIG_DIR/otel-collector.yaml"
    echo "  Services: /etc/systemd/system/oteldemo-*.service"
    echo
    echo "To view logs:"
    echo "  sudo journalctl -u otel-collector -f"
    echo "  sudo journalctl -u oteldemo-frontend -f"
}

main() {
    log_info "Starting OpenTelemetry Demo Vanilla Host Installation"
    
    check_root
    cleanup_previous_installation
    detect_os
    install_dependencies
    setup_docker
    create_users
    create_directories
    install_configs
    install_systemd_services
    setup_database
    configure_services
    enable_services
    setup_demo_services
    start_services
    check_installation
    show_next_steps
}

# Run main function
main "$@"
