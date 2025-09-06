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
    
    # Clean up package cache
    log_info "Cleaning package cache..."
    apt-get clean
    apt-get autoremove -y
    
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
    
    case $OS in
        "Ubuntu"|"Debian")
            apt-get update
            apt-get install -y wget curl unzip systemd postgresql postgresql-contrib redis-server \
                openjdk-11-jdk python3 python3-pip python3-venv \
                dotnet-sdk-8.0 golang-go php-cli php-curl php-json \
                build-essential cmake pkg-config libssl-dev \
                default-jre
            
            # Install Node.js 20+ from NodeSource
            curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
            apt-get install -y nodejs
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

download_otelcol() {
    log_info "Downloading OpenTelemetry Collector..."
    
    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        *)
            log_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
    
    # Download otelcol-contrib
    DOWNLOAD_URL="https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${OTELCOL_VERSION}/otelcol-contrib_${OTELCOL_VERSION}_linux_${ARCH}.tar.gz"
    
    log_info "Downloading from: $DOWNLOAD_URL"
    wget -O /tmp/otelcol-contrib.tar.gz "$DOWNLOAD_URL"
    
    # Extract and install
    tar -xzf /tmp/otelcol-contrib.tar.gz -C /tmp/
    cp /tmp/otelcol-contrib /usr/local/bin/
    chmod +x /usr/local/bin/otelcol-contrib
    
    # Cleanup
    rm -f /tmp/otelcol-contrib.tar.gz /tmp/otelcol-contrib
}

download_jaeger() {
    log_info "Downloading Jaeger..."
    
    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            ARCH="linux-amd64"
            ;;
        aarch64|arm64)
            ARCH="linux-arm64"
            ;;
        *)
            log_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
    
    # Download Jaeger
    JAEGER_VERSION="1.51.0"
    DOWNLOAD_URL="https://github.com/jaegertracing/jaeger/releases/download/v${JAEGER_VERSION}/jaeger-${JAEGER_VERSION}-${ARCH}.tar.gz"
    
    log_info "Downloading from: $DOWNLOAD_URL"
    wget -O /tmp/jaeger.tar.gz "$DOWNLOAD_URL"
    
    # Extract and install
    tar -xzf /tmp/jaeger.tar.gz -C /tmp/
    cp /tmp/jaeger-${JAEGER_VERSION}-${ARCH}/jaeger-all-in-one /usr/local/bin/
    chmod +x /usr/local/bin/jaeger-all-in-one
    
    # Cleanup
    rm -rf /tmp/jaeger.tar.gz /tmp/jaeger-${JAEGER_VERSION}-${ARCH}
}

download_kafka() {
    log_info "Downloading Apache Kafka..."
    
    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            ARCH=""
            ;;
        aarch64|arm64)
            ARCH="-aarch64"
            ;;
        *)
            log_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
    
    # Download Kafka
    KAFKA_VERSION="2.13-3.6.1"
    DOWNLOAD_URL="https://downloads.apache.org/kafka/3.6.1/kafka_${KAFKA_VERSION}.tgz"
    
    log_info "Downloading from: $DOWNLOAD_URL"
    wget -O /tmp/kafka.tgz "$DOWNLOAD_URL"
    
    # Extract and install
    tar -xzf /tmp/kafka.tgz -C /opt/
    mv /opt/kafka_${KAFKA_VERSION} /opt/kafka
    
    # Create symlinks
    ln -sf /opt/kafka/bin/kafka-server-start.sh /usr/local/bin/kafka-server-start
    ln -sf /opt/kafka/bin/kafka-topics.sh /usr/local/bin/kafka-topics
    ln -sf /opt/kafka/bin/zookeeper-server-start.sh /usr/local/bin/zookeeper-server-start
    
    # Set ownership
    chown -R kafka:kafka /opt/kafka 2>/dev/null || true
    
    # Cleanup
    rm -f /tmp/kafka.tgz
    
    log_success "Kafka installed to /opt/kafka"
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
    
    # Create jaeger user
    if ! id "jaeger" &>/dev/null; then
        useradd --system --no-create-home --shell /bin/false "jaeger"
        log_success "Created user: jaeger"
    else
        log_info "User jaeger already exists"
    fi
    
    # Create kafka user
    if ! id "kafka" &>/dev/null; then
        useradd --system --no-create-home --shell /bin/false "kafka"
        log_success "Created user: kafka"
    else
        log_info "User kafka already exists"
    fi
    
    # Create zookeeper user
    if ! id "zookeeper" &>/dev/null; then
        useradd --system --no-create-home --shell /bin/false "zookeeper"
        log_success "Created user: zookeeper"
    else
        log_info "User zookeeper already exists"
    fi
}

create_directories() {
    log_info "Creating directories..."
    
    # Create otelcol directories
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$DATA_DIR"
    mkdir -p "/var/lib/jaeger"
    mkdir -p "/var/lib/kafka-logs"
    mkdir -p "/opt/oteldemo"
    
    # Set ownership
    chown -R "$OTEL_USER:$OTEL_GROUP" "$CONFIG_DIR"
    chown -R "$OTEL_USER:$OTEL_GROUP" "$DATA_DIR"
    chown -R "jaeger:jaeger" "/var/lib/jaeger"
    chown -R "kafka:kafka" "/var/lib/kafka-logs"
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
    log_info "Installing systemd services..."
    
    # Copy service files
    cp services/*.service /etc/systemd/system/
    
    # Reload systemd
    systemctl daemon-reload
    
    log_success "Systemd services installed"
}

setup_database() {
    log_info "Setting up PostgreSQL database..."
    
    # Initialize PostgreSQL if needed
    if [[ ! -d "/var/lib/postgresql/data" ]]; then
        sudo -u postgres initdb -D /var/lib/postgresql/data
    fi
    
    # Create database and user
    sudo -u postgres psql -c "CREATE DATABASE otel;" || true
    sudo -u postgres psql -c "CREATE USER root WITH PASSWORD 'otel';" || true
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE otel TO root;" || true
    
    log_success "Database setup completed"
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
    log_info "Starting services..."
    
    # Start infrastructure services
    systemctl start postgresql
    systemctl start redis-server
    systemctl start otel-collector
    systemctl start jaeger
    systemctl start kafka
    systemctl start zookeeper
    
    # Start demo services
    systemctl start oteldemo-frontend
    systemctl start oteldemo-cart
    systemctl start oteldemo-checkout
    systemctl start oteldemo-currency
    systemctl start oteldemo-payment
    systemctl start oteldemo-product-catalog
    systemctl start oteldemo-load-generator
    
    log_success "All services started"
}

enable_services() {
    log_info "Enabling services..."
    
    # Enable infrastructure services
    systemctl enable postgresql redis-server
    systemctl enable otel-collector jaeger
    
    # Enable demo services (optional, can be started manually)
    systemctl enable oteldemo-frontend oteldemo-cart oteldemo-checkout \
        oteldemo-currency oteldemo-payment oteldemo-product-catalog \
        oteldemo-load-generator
    
    log_success "Services enabled"
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
    download_otelcol
    download_jaeger
    download_kafka
    create_users
    create_directories
    install_configs
    install_systemd_services
    setup_database
    configure_services
    enable_services
    setup_demo_services
    start_services
    show_next_steps
}

# Run main function
main "$@"
