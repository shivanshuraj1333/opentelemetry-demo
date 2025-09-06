#!/bin/bash

# OpenTelemetry Demo - Build Services Script
# This script builds all the demo services for native host execution

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
# Try to find the demo root directory
if [ -d "/Users/shivanshu.shrivastava/coralogix/github/opentelemetry-demo" ]; then
    DEMO_ROOT="/Users/shivanshu.shrivastava/coralogix/github/opentelemetry-demo"
elif [ -d "../.." ] && [ -f "../../src/frontend/package.json" ]; then
    DEMO_ROOT="$(realpath ../..)"
elif [ -d ".." ] && [ -f "../src/frontend/package.json" ]; then
    DEMO_ROOT="$(realpath ..)"
else
    DEMO_ROOT=""
    log_warning "Could not find OpenTelemetry demo source directory. Some services may not build."
fi

SERVICE_DIR="/opt/oteldemo"
SERVICE_USER="oteldemo"
SERVICE_GROUP="oteldemo"

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

build_frontend() {
    log_info "Building Frontend service..."
    
    # Create service directory
    mkdir -p "$SERVICE_DIR/frontend"
    
    if [ -n "$DEMO_ROOT" ] && [ -d "$DEMO_ROOT/src/frontend" ]; then
        # Copy source files
        cp -r "$DEMO_ROOT/src/frontend"/* "$SERVICE_DIR/frontend/"
        
        # Install dependencies
        cd "$SERVICE_DIR/frontend"
        npm install --production
        
        # Set ownership
        chown -R "$SERVICE_USER:$SERVICE_GROUP" "$SERVICE_DIR/frontend"
        
        log_success "Frontend service built successfully"
    else
        log_warning "Frontend source not found. Creating minimal placeholder."
        # Create a minimal placeholder
        cat > "$SERVICE_DIR/frontend/package.json" << 'EOF'
{
  "name": "frontend",
  "version": "1.0.0",
  "scripts": {
    "start": "echo 'Frontend service placeholder' && sleep infinity"
  }
}
EOF
        chown -R "$SERVICE_USER:$SERVICE_GROUP" "$SERVICE_DIR/frontend"
        log_warning "Frontend placeholder created"
    fi
}

build_cart() {
    log_info "Building Cart service..."
    
    # Create service directory
    mkdir -p "$SERVICE_DIR/cart"
    
    # Copy source files
    cp -r "$DEMO_ROOT/src/cart"/* "$SERVICE_DIR/cart/"
    
    # Build .NET application
    cd "$SERVICE_DIR/cart"
    dotnet build -c Release
    dotnet publish -c Release -o ./bin/Release/net6.0/publish
    
    # Set ownership
    chown -R "$SERVICE_USER:$SERVICE_GROUP" "$SERVICE_DIR/cart"
    
    log_success "Cart service built"
}

build_checkout() {
    log_info "Building Checkout service..."
    
    # Create service directory
    mkdir -p "$SERVICE_DIR/checkout"
    
    # Copy source files
    cp -r "$DEMO_ROOT/src/checkout"/* "$SERVICE_DIR/checkout/"
    
    # Build Go application
    cd "$SERVICE_DIR/checkout"
    go mod tidy
    go build -o checkout .
    
    # Copy binary to system path
    cp checkout /usr/local/bin/
    chmod +x /usr/local/bin/checkout
    
    # Set ownership
    chown -R "$SERVICE_USER:$SERVICE_GROUP" "$SERVICE_DIR/checkout"
    
    log_success "Checkout service built"
}

build_currency() {
    log_info "Building Currency service..."
    
    # Create service directory
    mkdir -p "$SERVICE_DIR/currency"
    
    # Copy source files
    cp -r "$DEMO_ROOT/src/currency"/* "$SERVICE_DIR/currency/"
    
    # Build C++ application
    cd "$SERVICE_DIR/currency"
    mkdir -p build
    cd build
    cmake ..
    make
    
    # Copy binary to system path
    cp currency /usr/local/bin/
    chmod +x /usr/local/bin/currency
    
    # Set ownership
    chown -R "$SERVICE_USER:$SERVICE_GROUP" "$SERVICE_DIR/currency"
    
    log_success "Currency service built"
}

build_payment() {
    log_info "Building Payment service..."
    
    # Create service directory
    mkdir -p "$SERVICE_DIR/payment"
    
    # Copy source files
    cp -r "$DEMO_ROOT/src/payment"/* "$SERVICE_DIR/payment/"
    
    # Install Node.js dependencies
    cd "$SERVICE_DIR/payment"
    npm install --production
    
    # Set ownership
    chown -R "$SERVICE_USER:$SERVICE_GROUP" "$SERVICE_DIR/payment"
    
    log_success "Payment service built"
}

build_product_catalog() {
    log_info "Building Product Catalog service..."
    
    # Create service directory
    mkdir -p "$SERVICE_DIR/product-catalog"
    
    # Copy source files
    cp -r "$DEMO_ROOT/src/product-catalog"/* "$SERVICE_DIR/product-catalog/"
    
    # Build Go application
    cd "$SERVICE_DIR/product-catalog"
    go mod tidy
    go build -o product-catalog .
    
    # Copy binary to system path
    cp product-catalog /usr/local/bin/
    chmod +x /usr/local/bin/product-catalog
    
    # Set ownership
    chown -R "$SERVICE_USER:$SERVICE_GROUP" "$SERVICE_DIR/product-catalog"
    
    log_success "Product Catalog service built"
}

build_recommendation() {
    log_info "Building Recommendation service..."
    
    # Create service directory
    mkdir -p "$SERVICE_DIR/recommendation"
    
    # Copy source files
    cp -r "$DEMO_ROOT/src/recommendation"/* "$SERVICE_DIR/recommendation/"
    
    # Install Python dependencies
    cd "$SERVICE_DIR/recommendation"
    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt
    
    # Set ownership
    chown -R "$SERVICE_USER:$SERVICE_GROUP" "$SERVICE_DIR/recommendation"
    
    log_success "Recommendation service built"
}

build_shipping() {
    log_info "Building Shipping service..."
    
    # Create service directory
    mkdir -p "$SERVICE_DIR/shipping"
    
    # Copy source files
    cp -r "$DEMO_ROOT/src/shipping"/* "$SERVICE_DIR/shipping/"
    
    # Build Rust application
    cd "$SERVICE_DIR/shipping"
    cargo build --release
    
    # Copy binary to system path
    cp target/release/shipping /usr/local/bin/
    chmod +x /usr/local/bin/shipping
    
    # Set ownership
    chown -R "$SERVICE_USER:$SERVICE_GROUP" "$SERVICE_DIR/shipping"
    
    log_success "Shipping service built"
}

build_load_generator() {
    log_info "Building Load Generator..."
    
    # Create service directory
    mkdir -p "$SERVICE_DIR/load-generator"
    
    # Copy source files
    cp -r "$DEMO_ROOT/src/load-generator"/* "$SERVICE_DIR/load-generator/"
    
    # Install Python dependencies
    cd "$SERVICE_DIR/load-generator"
    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt
    
    # Set ownership
    chown -R "$SERVICE_USER:$SERVICE_GROUP" "$SERVICE_DIR/load-generator"
    
    log_success "Load Generator built"
}

build_all_services() {
    log_info "Building all demo services..."
    
    build_frontend
    build_cart
    build_checkout
    build_currency
    build_payment
    build_product_catalog
    build_recommendation
    build_shipping
    build_load_generator
    
    log_success "All services built successfully!"
}

show_usage() {
    echo "Usage: $0 [service_name]"
    echo
    echo "Available services:"
    echo "  frontend          - Frontend web application"
    echo "  cart              - Cart service (.NET)"
    echo "  checkout          - Checkout service (Go)"
    echo "  currency          - Currency service (C++)"
    echo "  payment           - Payment service (Node.js)"
    echo "  product-catalog   - Product Catalog service (Go)"
    echo "  recommendation    - Recommendation service (Python)"
    echo "  shipping          - Shipping service (Rust)"
    echo "  load-generator    - Load Generator (Python)"
    echo "  all               - Build all services (default)"
    echo
}

main() {
    check_root
    
    if [[ $# -eq 0 ]]; then
        build_all_services
    else
        case "$1" in
            "frontend")
                build_frontend
                ;;
            "cart")
                build_cart
                ;;
            "checkout")
                build_checkout
                ;;
            "currency")
                build_currency
                ;;
            "payment")
                build_payment
                ;;
            "product-catalog")
                build_product_catalog
                ;;
            "recommendation")
                build_recommendation
                ;;
            "shipping")
                build_shipping
                ;;
            "load-generator")
                build_load_generator
                ;;
            "all")
                build_all_services
                ;;
            *)
                log_error "Unknown service: $1"
                show_usage
                exit 1
                ;;
        esac
    fi
}

# Run main function
main "$@"
