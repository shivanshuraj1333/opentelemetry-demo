#!/bin/bash

# OpenTelemetry Demo - Pure Host Native Installation Script
# This script installs all dependencies and services directly on the host without containers

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DEMO_USER="oteldemo"
DEMO_HOME="/opt/oteldemo"
SERVICES_DIR="/etc/systemd/system"
OTELCOL_VERSION="0.131.1"
OTELCOL_CONTRIB_VERSION="0.131.1"

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

install_system_dependencies() {
    log_info "Installing system dependencies..."
    
    case $OS in
        "Ubuntu"|"Debian")
            apt-get update
            apt-get install -y wget curl unzip systemd build-essential git
            apt-get install -y nodejs npm python3 python3-pip python3-venv
            apt-get install -y openjdk-11-jdk golang-go rustc cargo
            apt-get install -y php php-cli php-json php-mbstring
            apt-get install -y postgresql postgresql-contrib redis-server
            apt-get install -y default-jre-headless
            ;;
        "CentOS"|"Red Hat Enterprise Linux"|"Rocky Linux"|"AlmaLinux")
            yum update -y
            yum groupinstall -y "Development Tools"
            yum install -y wget curl unzip systemd git
            yum install -y nodejs npm python3 python3-pip
            yum install -y java-11-openjdk-devel golang rust cargo
            yum install -y php php-cli php-json php-mbstring
            yum install -y postgresql postgresql-server redis
            yum install -y java-11-openjdk-headless
            ;;
        "Amazon Linux")
            yum update -y
            yum groupinstall -y "Development Tools"
            yum install -y wget curl unzip systemd git
            yum install -y nodejs npm python3 python3-pip
            yum install -y java-11-openjdk-devel golang rust cargo
            yum install -y php php-cli php-json php-mbstring
            yum install -y postgresql postgresql-server redis
            yum install -y java-11-openjdk-headless
            ;;
        *)
            log_warning "Unsupported OS: $OS. Please install dependencies manually."
            ;;
    esac
}

install_kafka() {
    log_info "Installing Apache Kafka..."
    
    # Create kafka user
    if ! id "kafka" &>/dev/null; then
        useradd --system --no-create-home --shell /bin/false kafka
    fi
    
    # Download and install Kafka
    KAFKA_VERSION="2.13-3.6.0"
    KAFKA_URL="https://downloads.apache.org/kafka/3.6.0/kafka_${KAFKA_VERSION}.tgz"
    
    cd /opt
    wget "$KAFKA_URL"
    tar -xzf "kafka_${KAFKA_VERSION}.tgz"
    mv "kafka_${KAFKA_VERSION}" kafka
    rm "kafka_${KAFKA_VERSION}.tgz"
    
    # Set ownership
    chown -R kafka:kafka /opt/kafka
    
    # Create data directories
    mkdir -p /var/lib/kafka
    mkdir -p /var/lib/zookeeper
    chown -R kafka:kafka /var/lib/kafka /var/lib/zookeeper
    
    log_success "Kafka installed"
}

install_otelcol() {
    log_info "Installing OpenTelemetry Collector..."
    
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
    
    wget -O /tmp/otelcol-contrib.tar.gz "$DOWNLOAD_URL"
    tar -xzf /tmp/otelcol-contrib.tar.gz -C /tmp/
    cp /tmp/otelcol-contrib /usr/local/bin/
    chmod +x /usr/local/bin/otelcol-contrib
    rm -f /tmp/otelcol-contrib.tar.gz /tmp/otelcol-contrib
    
    log_success "OpenTelemetry Collector installed"
}

create_demo_user() {
    log_info "Creating demo user..."
    
    if ! id "$DEMO_USER" &>/dev/null; then
        useradd --system --create-home --shell /bin/bash "$DEMO_USER"
        usermod -aG postgres "$DEMO_USER" 2>/dev/null || true
        usermod -aG redis "$DEMO_USER" 2>/dev/null || true
        usermod -aG kafka "$DEMO_USER" 2>/dev/null || true
        log_success "Created user: $DEMO_USER"
    else
        log_info "User $DEMO_USER already exists"
    fi
}

create_directories() {
    log_info "Creating directories..."
    
    mkdir -p "$DEMO_HOME"
    mkdir -p /etc/otelcol
    mkdir -p /var/lib/otelcol
    
    # Create service directories
    for service in frontend cart checkout currency email payment product-catalog quote recommendation shipping load-generator; do
        mkdir -p "$DEMO_HOME/$service"
    done
    
    chown -R "$DEMO_USER:$DEMO_USER" "$DEMO_HOME"
    chown -R otelcol:otelcol /etc/otelcol /var/lib/otelcol
    
    log_success "Directories created"
}

install_coralogix_configs() {
    log_info "Installing Coralogix configurations..."
    
    # Copy configuration files
    cp agent.yaml /etc/otelcol/
    cp collector.yaml /etc/otelcol/
    
    # Set permissions
    chown -R otelcol:otelcol /etc/otelcol
    chmod 644 /etc/otelcol/*.yaml
    
    log_success "Coralogix configurations installed"
}

install_systemd_services() {
    log_info "Installing systemd services..."
    
    # Copy all service files
    cp services/*.service /etc/systemd/system/
    
    # Reload systemd
    systemctl daemon-reload
    
    log_success "Systemd services installed"
}

setup_postgresql() {
    log_info "Setting up PostgreSQL..."
    
    # Initialize database (Ubuntu/Debian)
    if command -v pg_ctl &> /dev/null; then
        if [ ! -d "/var/lib/postgresql/data" ]; then
            sudo -u postgres initdb -D /var/lib/postgresql/data
        fi
    fi
    
    # Start and enable PostgreSQL
    systemctl enable postgresql
    systemctl start postgresql
    
    # Create database and user
    sudo -u postgres psql -c "CREATE DATABASE otel;"
    sudo -u postgres psql -c "CREATE USER root WITH PASSWORD 'otel';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE otel TO root;"
    
    log_success "PostgreSQL configured"
}

setup_redis() {
    log_info "Setting up Redis..."
    
    # Start and enable Redis
    systemctl enable redis
    systemctl start redis
    
    log_success "Redis configured"
}

setup_kafka() {
    log_info "Setting up Kafka..."
    
    # Start Zookeeper first
    systemctl enable zookeeper
    systemctl start zookeeper
    
    # Wait for Zookeeper to be ready
    sleep 10
    
    # Start Kafka
    systemctl enable kafka
    systemctl start kafka
    
    log_success "Kafka configured"
}

create_env_file() {
    log_info "Creating environment file..."
    
    cat > /etc/otelcol/coralogix.env << EOF
# Coralogix Configuration
CORALOGIX_PRIVATE_KEY=YOUR_PRIVATE_KEY_HERE
CORALOGIX_DOMAIN=app.staging.coralogix.net
EOF
    
    chown otelcol:otelcol /etc/otelcol/coralogix.env
    chmod 600 /etc/otelcol/coralogix.env
    
    log_success "Environment file created"
}

enable_services() {
    log_info "Enabling services..."
    
    # Enable Coralogix services
    systemctl enable coralogix-agent
    systemctl enable coralogix-collector
    
    # Enable infrastructure services
    systemctl enable postgresql
    systemctl enable redis
    systemctl enable zookeeper
    systemctl enable kafka
    
    # Enable demo services
    for service in frontend cart checkout currency email payment product-catalog quote recommendation shipping load-generator; do
        systemctl enable "oteldemo-$service"
    done
    
    log_success "Services enabled"
}

create_build_scripts() {
    log_info "Creating build scripts..."
    
    # Create a build script for demo services
    cat > "$DEMO_HOME/build-services.sh" << 'EOF'
#!/bin/bash

# Build script for OpenTelemetry Demo services
set -e

DEMO_HOME="/opt/oteldemo"
cd "$DEMO_HOME"

echo "Building OpenTelemetry Demo services..."

# Frontend (Node.js)
if [ -d "frontend" ]; then
    echo "Building frontend..."
    cd frontend
    npm install
    npm run build
    cd ..
fi

# Cart (C#/.NET)
if [ -d "cart" ]; then
    echo "Building cart service..."
    cd cart
    dotnet build -c Release
    dotnet publish -c Release -o bin/publish
    cd ..
fi

# Checkout (Go)
if [ -d "checkout" ]; then
    echo "Building checkout service..."
    cd checkout
    go mod tidy
    go build -o checkout main.go
    cp checkout /usr/local/bin/
    cd ..
fi

# Currency (C++)
if [ -d "currency" ]; then
    echo "Building currency service..."
    cd currency
    mkdir -p build
    cd build
    cmake ..
    make
    cp currency /usr/local/bin/
    cd ../..
fi

# Email (Ruby)
if [ -d "email" ]; then
    echo "Building email service..."
    cd email
    bundle install
    cd ..
fi

# Payment (Node.js)
if [ -d "payment" ]; then
    echo "Building payment service..."
    cd payment
    npm install
    cd ..
fi

# Product Catalog (Go)
if [ -d "product-catalog" ]; then
    echo "Building product-catalog service..."
    cd product-catalog
    go mod tidy
    go build -o product-catalog main.go
    cp product-catalog /usr/local/bin/
    cd ..
fi

# Quote (PHP)
if [ -d "quote" ]; then
    echo "Building quote service..."
    cd quote
    composer install
    cd ..
fi

# Recommendation (Python)
if [ -d "recommendation" ]; then
    echo "Building recommendation service..."
    cd recommendation
    pip3 install -r requirements.txt
    cd ..
fi

# Shipping (Rust)
if [ -d "shipping" ]; then
    echo "Building shipping service..."
    cd shipping
    cargo build --release
    cp target/release/shipping /usr/local/bin/
    cd ..
fi

# Load Generator (Python)
if [ -d "load-generator" ]; then
    echo "Building load generator..."
    cd load-generator
    pip3 install -r requirements.txt
    cd ..
fi

echo "All services built successfully!"
EOF

    chmod +x "$DEMO_HOME/build-services.sh"
    chown "$DEMO_USER:$DEMO_USER" "$DEMO_HOME/build-services.sh"
    
    log_success "Build scripts created"
}

show_next_steps() {
    log_success "Pure host native installation completed!"
    echo
    echo "Next steps:"
    echo "1. Set your Coralogix private key:"
    echo "   sudo nano /etc/otelcol/coralogix.env"
    echo
    echo "2. Copy demo service source code to /opt/oteldemo/"
    echo "3. Build the services:"
    echo "   sudo -u oteldemo /opt/oteldemo/build-services.sh"
    echo
    echo "4. Start Coralogix services:"
    echo "   sudo systemctl start coralogix-agent"
    echo "   sudo systemctl start coralogix-collector"
    echo
    echo "5. Start infrastructure services:"
    echo "   sudo systemctl start postgresql redis zookeeper kafka"
    echo
    echo "6. Start demo services:"
    echo "   sudo systemctl start oteldemo-frontend"
    echo "   sudo systemctl start oteldemo-cart"
    echo "   # ... start other services as needed"
    echo
    echo "7. Check service status:"
    echo "   sudo systemctl status oteldemo-*"
    echo
    echo "Access points:"
    echo "  Frontend: http://localhost:3000"
    echo "  Load Generator: http://localhost:8090"
    echo "  Coralogix Agent Health: http://localhost:13133"
}

main() {
    log_info "Starting Pure Host Native Installation"
    
    check_root
    detect_os
    install_system_dependencies
    install_kafka
    install_otelcol
    create_demo_user
    create_directories
    # install_coralogix_configs
    install_systemd_services
    setup_postgresql
    setup_redis
    setup_kafka
    create_env_file
    enable_services
    create_build_scripts
    show_next_steps
}

# Run main function
main "$@"
