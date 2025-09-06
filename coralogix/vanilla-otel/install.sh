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

# Check root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    exit 1
fi

# Service definitions with ports and languages
declare -A SERVICES=(
    ["accounting"]="8080 .NET"
    ["ad"]="8081 Java"
    ["cart"]="8082 .NET"
    ["checkout"]="8083 Go"
    ["currency"]="8084 C++"
    ["email"]="8085 Ruby"
    ["fraud-detection"]="8086 Kotlin"
    ["frontend"]="3000 Node.js"
    ["frontend-proxy"]="8087 Envoy"
    ["image-provider"]="8088 Nginx"
    ["load-generator"]="8089 Python"
    ["payment"]="8090 Node.js"
    ["product-catalog"]="8091 Go"
    ["quote"]="8092 PHP"
    ["recommendation"]="8093 Python"
    ["shipping"]="8094 Rust"
)

# Install dependencies
log_info "Installing dependencies..."

# Fix any broken packages first
apt-get update
apt-get install -f -y

# Remove conflicting packages
apt-get remove -y containerd npm || true

# Install basic dependencies
apt-get install -y \
    curl \
    wget \
    gnupg \
    lsb-release \
    ca-certificates \
    software-properties-common

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Install Node.js 20+ (this will handle npm)
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# Install other dependencies
apt-get install -y \
    python3 \
    python3-pip \
    dotnet-sdk-8.0 \
    openjdk-17-jdk \
    golang-go \
    build-essential \
    cmake \
    ruby \
    ruby-dev \
    rustc \
    cargo \
    nginx \
    netcat-openbsd

# Start Docker
systemctl start docker
systemctl enable docker

# Create user
useradd --system --no-create-home --shell /bin/false oteldemo || true

# Create directories
mkdir -p /opt/oteldemo
chown -R oteldemo:oteldemo /opt/oteldemo

# Start infrastructure
log_info "Starting infrastructure services..."
docker compose up -d

# Wait for services
log_info "Waiting for infrastructure services to be ready..."
sleep 30

# Create demo services
log_info "Creating demo services..."
./create-services.sh

# Create systemd services
log_info "Creating systemd services..."
./create-systemd.sh

log_success "Installation completed!"
echo
echo "🌐 Access the demo:"
echo "  Frontend: http://localhost:3000"
echo "  Jaeger UI: http://localhost:16686"
echo "  Grafana: http://localhost:3001 (admin/admin)"
echo "  Prometheus: http://localhost:9090"
echo "  Flagd UI: http://localhost:8080"
echo
echo "🔧 Management:"
echo "  Infrastructure: docker compose up|down|ps"
echo "  Demo services: systemctl start|stop|status oteldemo-*"
echo
echo "📊 All services running on ports:"
echo "  accounting: http://localhost:8080"
echo "  ad: http://localhost:8081"
echo "  cart: http://localhost:8082"
echo "  checkout: http://localhost:8083"
echo "  currency: http://localhost:8084"
echo "  email: http://localhost:8085"
echo "  fraud-detection: http://localhost:8086"
echo "  frontend: http://localhost:3000"
echo "  frontend-proxy: http://localhost:8087"
echo "  image-provider: http://localhost:8088"
echo "  load-generator: http://localhost:8089"
echo "  payment: http://localhost:8090"
echo "  product-catalog: http://localhost:8091"
echo "  quote: http://localhost:8092"
echo "  recommendation: http://localhost:8093"
echo "  shipping: http://localhost:8094"