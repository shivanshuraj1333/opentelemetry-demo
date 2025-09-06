#!/bin/bash

# Coralogix OpenTelemetry Host Installation Script
# This script installs and configures Coralogix OpenTelemetry Agent and Collector on a host system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
OTELCOL_VERSION="0.131.1"
OTELCOL_CONTRIB_VERSION="0.131.1"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/otelcol"
DATA_DIR="/var/lib/otelcol"
SERVICE_USER="otelcol"
SERVICE_GROUP="otelcol"

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
            apt-get install -y wget curl unzip systemd
            ;;
        "CentOS"|"Red Hat Enterprise Linux"|"Rocky Linux"|"AlmaLinux")
            yum update -y
            yum install -y wget curl unzip systemd
            ;;
        "Amazon Linux")
            yum update -y
            yum install -y wget curl unzip systemd
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
    DOWNLOAD_URL="https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${OTELCOL_CONTRIB_VERSION}/otelcol-contrib_${OTELCOL_CONTRIB_VERSION}_linux_${ARCH}.tar.gz"
    
    log_info "Downloading from: $DOWNLOAD_URL"
    wget -O /tmp/otelcol-contrib.tar.gz "$DOWNLOAD_URL"
    
    # Extract and install
    tar -xzf /tmp/otelcol-contrib.tar.gz -C /tmp/
    cp /tmp/otelcol-contrib /usr/local/bin/
    chmod +x /usr/local/bin/otelcol-contrib
    
    # Cleanup
    rm -f /tmp/otelcol-contrib.tar.gz /tmp/otelcol-contrib
}

create_user() {
    log_info "Creating service user and group..."
    
    if ! id "$SERVICE_USER" &>/dev/null; then
        useradd --system --no-create-home --shell /bin/false "$SERVICE_USER"
        log_success "Created user: $SERVICE_USER"
    else
        log_info "User $SERVICE_USER already exists"
    fi
}

create_directories() {
    log_info "Creating directories..."
    
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$DATA_DIR"
    
    chown -R "$SERVICE_USER:$SERVICE_GROUP" "$CONFIG_DIR"
    chown -R "$SERVICE_USER:$SERVICE_GROUP" "$DATA_DIR"
    
    log_success "Created directories: $CONFIG_DIR, $DATA_DIR"
}

install_configs() {
    log_info "Installing configuration files..."
    
    # Copy configuration files
    cp agent.yaml "$CONFIG_DIR/"
    cp collector.yaml "$CONFIG_DIR/"
    
    # Set permissions
    chown -R "$SERVICE_USER:$SERVICE_GROUP" "$CONFIG_DIR"
    chmod 644 "$CONFIG_DIR"/*.yaml
    
    log_success "Configuration files installed"
}

install_systemd_services() {
    log_info "Installing systemd services..."
    
    # Copy service files
    cp coralogix-agent.service /etc/systemd/system/
    cp coralogix-collector.service /etc/systemd/system/
    
    # Reload systemd
    systemctl daemon-reload
    
    log_success "Systemd services installed"
}

create_env_file() {
    log_info "Creating environment file template..."
    
    cat > "$CONFIG_DIR/coralogix.env" << EOF
# Coralogix Configuration
# Replace YOUR_PRIVATE_KEY with your actual Coralogix private key
CORALOGIX_PRIVATE_KEY=YOUR_PRIVATE_KEY

# Optional: Override default domain
# CORALOGIX_DOMAIN=app.staging.coralogix.net
EOF
    
    chown "$SERVICE_USER:$SERVICE_GROUP" "$CONFIG_DIR/coralogix.env"
    chmod 600 "$CONFIG_DIR/coralogix.env"
    
    log_success "Environment file created: $CONFIG_DIR/coralogix.env"
}

enable_services() {
    log_info "Enabling services..."
    
    systemctl enable coralogix-agent
    systemctl enable coralogix-collector
    
    log_success "Services enabled"
}

show_next_steps() {
    log_success "Installation completed!"
    echo
    echo "Next steps:"
    echo "1. Edit $CONFIG_DIR/coralogix.env and set your CORALOGIX_PRIVATE_KEY"
    echo "2. Start the services:"
    echo "   sudo systemctl start coralogix-agent"
    echo "   sudo systemctl start coralogix-collector"
    echo "3. Check service status:"
    echo "   sudo systemctl status coralogix-agent"
    echo "   sudo systemctl status coralogix-collector"
    echo "4. View logs:"
    echo "   sudo journalctl -u coralogix-agent -f"
    echo "   sudo journalctl -u coralogix-collector -f"
    echo
    echo "Configuration files:"
    echo "  Agent: $CONFIG_DIR/agent.yaml"
    echo "  Collector: $CONFIG_DIR/collector.yaml"
    echo "  Environment: $CONFIG_DIR/coralogix.env"
}

main() {
    log_info "Starting Coralogix OpenTelemetry Host Installation"
    
    check_root
    detect_os
    install_dependencies
    download_otelcol
    create_user
    create_directories
    install_configs
    install_systemd_services
    create_env_file
    enable_services
    show_next_steps
}

# Run main function
main "$@"
