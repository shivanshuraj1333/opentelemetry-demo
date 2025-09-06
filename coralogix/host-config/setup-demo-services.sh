#!/bin/bash

# OpenTelemetry Demo Services Setup Script
# This script copies source code and sets up demo services on the host

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
SOURCE_DIR="/Users/shivanshu.shrivastava/coralogix/github/opentelemetry-demo/src"

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

copy_source_code() {
    log_info "Copying demo service source code..."
    
    # Copy each service
    services=("frontend" "cart" "checkout" "currency" "email" "payment" "product-catalog" "quote" "recommendation" "shipping" "load-generator")
    
    for service in "${services[@]}"; do
        if [ -d "$SOURCE_DIR/$service" ]; then
            log_info "Copying $service..."
            cp -r "$SOURCE_DIR/$service" "$DEMO_HOME/"
            chown -R "$DEMO_USER:$DEMO_USER" "$DEMO_HOME/$service"
        else
            log_warning "Source directory for $service not found: $SOURCE_DIR/$service"
        fi
    done
    
    log_success "Source code copied"
}

setup_frontend() {
    log_info "Setting up frontend service..."
    
    cd "$DEMO_HOME/frontend"
    
    # Install dependencies
    sudo -u "$DEMO_USER" npm install
    
    # Create package.json if it doesn't exist
    if [ ! -f "package.json" ]; then
        cat > package.json << 'EOF'
{
  "name": "frontend",
  "version": "1.0.0",
  "scripts": {
    "start": "next start -p 3000",
    "dev": "next dev -p 3000",
    "build": "next build"
  },
  "dependencies": {
    "next": "^13.0.0",
    "react": "^18.0.0",
    "react-dom": "^18.0.0"
  }
}
EOF
    fi
    
    # Build the application
    sudo -u "$DEMO_USER" npm run build
    
    log_success "Frontend service set up"
}

setup_cart() {
    log_info "Setting up cart service..."
    
    cd "$DEMO_HOME/cart"
    
    # Create project file if it doesn't exist
    if [ ! -f "cart.csproj" ]; then
        cat > cart.csproj << 'EOF'
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net6.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.AspNetCore.OpenApi" Version="6.0.0" />
    <PackageReference Include="Swashbuckle.AspNetCore" Version="6.0.0" />
  </ItemGroup>
</Project>
EOF
    fi
    
    # Build the service
    sudo -u "$DEMO_USER" dotnet build -c Release
    sudo -u "$DEMO_USER" dotnet publish -c Release -o bin/publish
    
    log_success "Cart service set up"
}

setup_checkout() {
    log_info "Setting up checkout service..."
    
    cd "$DEMO_HOME/checkout"
    
    # Create go.mod if it doesn't exist
    if [ ! -f "go.mod" ]; then
        cat > go.mod << 'EOF'
module checkout

go 1.19

require (
    go.opentelemetry.io/otel v1.16.0
    go.opentelemetry.io/otel/trace v1.16.0
)
EOF
    fi
    
    # Build the service
    sudo -u "$DEMO_USER" go mod tidy
    sudo -u "$DEMO_USER" go build -o checkout main.go
    cp checkout /usr/local/bin/
    
    log_success "Checkout service set up"
}

setup_currency() {
    log_info "Setting up currency service..."
    
    cd "$DEMO_HOME/currency"
    
    # Create CMakeLists.txt if it doesn't exist
    if [ ! -f "CMakeLists.txt" ]; then
        cat > CMakeLists.txt << 'EOF'
cmake_minimum_required(VERSION 3.10)
project(currency)

set(CMAKE_CXX_STANDARD 17)

find_package(PkgConfig REQUIRED)
pkg_check_modules(GRPC REQUIRED grpc++)
pkg_check_modules(PROTOBUF REQUIRED protobuf)

add_executable(currency main.cpp)
target_link_libraries(currency ${GRPC_LIBRARIES} ${PROTOBUF_LIBRARIES})
target_include_directories(currency PRIVATE ${GRPC_INCLUDE_DIRS} ${PROTOBUF_INCLUDE_DIRS})
target_compile_options(currency PRIVATE ${GRPC_CFLAGS_OTHER})
EOF
    fi
    
    # Build the service
    mkdir -p build
    cd build
    cmake ..
    make
    cp currency /usr/local/bin/
    cd ..
    
    log_success "Currency service set up"
}

setup_email() {
    log_info "Setting up email service..."
    
    cd "$DEMO_HOME/email"
    
    # Create Gemfile if it doesn't exist
    if [ ! -f "Gemfile" ]; then
        cat > Gemfile << 'EOF'
source 'https://rubygems.org'

gem 'sinatra', '~> 2.0'
gem 'puma', '~> 5.0'
gem 'json', '~> 2.0'
EOF
    fi
    
    # Install dependencies
    sudo -u "$DEMO_USER" bundle install
    
    log_success "Email service set up"
}

setup_payment() {
    log_info "Setting up payment service..."
    
    cd "$DEMO_HOME/payment"
    
    # Create package.json if it doesn't exist
    if [ ! -f "package.json" ]; then
        cat > package.json << 'EOF'
{
  "name": "payment",
  "version": "1.0.0",
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "express": "^4.18.0",
    "cors": "^2.8.5"
  }
}
EOF
    fi
    
    # Install dependencies
    sudo -u "$DEMO_USER" npm install
    
    log_success "Payment service set up"
}

setup_product_catalog() {
    log_info "Setting up product-catalog service..."
    
    cd "$DEMO_HOME/product-catalog"
    
    # Create go.mod if it doesn't exist
    if [ ! -f "go.mod" ]; then
        cat > go.mod << 'EOF'
module product-catalog

go 1.19

require (
    go.opentelemetry.io/otel v1.16.0
    go.opentelemetry.io/otel/trace v1.16.0
)
EOF
    fi
    
    # Build the service
    sudo -u "$DEMO_USER" go mod tidy
    sudo -u "$DEMO_USER" go build -o product-catalog main.go
    cp product-catalog /usr/local/bin/
    
    log_success "Product-catalog service set up"
}

setup_quote() {
    log_info "Setting up quote service..."
    
    cd "$DEMO_HOME/quote"
    
    # Create composer.json if it doesn't exist
    if [ ! -f "composer.json" ]; then
        cat > composer.json << 'EOF'
{
    "require": {
        "php": ">=7.4"
    },
    "autoload": {
        "psr-4": {
            "App\\": "src/"
        }
    }
}
EOF
    fi
    
    # Install dependencies
    sudo -u "$DEMO_USER" composer install
    
    log_success "Quote service set up"
}

setup_recommendation() {
    log_info "Setting up recommendation service..."
    
    cd "$DEMO_HOME/recommendation"
    
    # Create requirements.txt if it doesn't exist
    if [ ! -f "requirements.txt" ]; then
        cat > requirements.txt << 'EOF'
flask==2.3.0
requests==2.31.0
opentelemetry-api==1.16.0
opentelemetry-sdk==1.16.0
opentelemetry-exporter-otlp==1.16.0
opentelemetry-instrumentation-flask==0.38b0
opentelemetry-instrumentation-requests==0.38b0
EOF
    fi
    
    # Install dependencies
    sudo -u "$DEMO_USER" pip3 install -r requirements.txt
    
    log_success "Recommendation service set up"
}

setup_shipping() {
    log_info "Setting up shipping service..."
    
    cd "$DEMO_HOME/shipping"
    
    # Create Cargo.toml if it doesn't exist
    if [ ! -f "Cargo.toml" ]; then
        cat > Cargo.toml << 'EOF'
[package]
name = "shipping"
version = "0.1.0"
edition = "2021"

[dependencies]
tokio = { version = "1.0", features = ["full"] }
tonic = "0.9"
prost = "0.11"
tracing = "0.1"
tracing-subscriber = "0.3"
opentelemetry = "0.18"
opentelemetry-otlp = "0.11"
EOF
    fi
    
    # Build the service
    sudo -u "$DEMO_USER" cargo build --release
    cp target/release/shipping /usr/local/bin/
    
    log_success "Shipping service set up"
}

setup_load_generator() {
    log_info "Setting up load generator..."
    
    cd "$DEMO_HOME/load-generator"
    
    # Create requirements.txt if it doesn't exist
    if [ ! -f "requirements.txt" ]; then
        cat > requirements.txt << 'EOF'
locust==2.16.0
requests==2.31.0
opentelemetry-api==1.16.0
opentelemetry-sdk==1.16.0
opentelemetry-exporter-otlp==1.16.0
opentelemetry-instrumentation-requests==0.38b0
EOF
    fi
    
    # Install dependencies
    sudo -u "$DEMO_USER" pip3 install -r requirements.txt
    
    log_success "Load generator set up"
}

create_startup_script() {
    log_info "Creating startup script..."
    
    cat > "$DEMO_HOME/start-all-services.sh" << 'EOF'
#!/bin/bash

# Start all OpenTelemetry Demo services
set -e

echo "Starting OpenTelemetry Demo services..."

# Start infrastructure services
echo "Starting infrastructure services..."
systemctl start postgresql
systemctl start redis
systemctl start zookeeper
sleep 5
systemctl start kafka

# Start Coralogix services
echo "Starting Coralogix services..."
systemctl start coralogix-agent
systemctl start coralogix-collector

# Start demo services
echo "Starting demo services..."
systemctl start oteldemo-frontend
systemctl start oteldemo-cart
systemctl start oteldemo-currency
systemctl start oteldemo-email
systemctl start oteldemo-payment
systemctl start oteldemo-product-catalog
systemctl start oteldemo-quote
systemctl start oteldemo-recommendation
systemctl start oteldemo-shipping
systemctl start oteldemo-checkout
systemctl start oteldemo-load-generator

echo "All services started!"
echo "Frontend: http://localhost:3000"
echo "Load Generator: http://localhost:8090"
echo "Coralogix Agent Health: http://localhost:13133"
EOF

    chmod +x "$DEMO_HOME/start-all-services.sh"
    chown "$DEMO_USER:$DEMO_USER" "$DEMO_HOME/start-all-services.sh"
    
    log_success "Startup script created"
}

show_next_steps() {
    log_success "Demo services setup completed!"
    echo
    echo "Next steps:"
    echo "1. Set your Coralogix private key:"
    echo "   sudo nano /etc/otelcol/coralogix.env"
    echo
    echo "2. Start all services:"
    echo "   sudo /opt/oteldemo/start-all-services.sh"
    echo
    echo "3. Or start services individually:"
    echo "   sudo systemctl start coralogix-agent coralogix-collector"
    echo "   sudo systemctl start postgresql redis zookeeper kafka"
    echo "   sudo systemctl start oteldemo-frontend"
    echo "   # ... start other services as needed"
    echo
    echo "4. Check service status:"
    echo "   sudo systemctl status oteldemo-*"
    echo
    echo "5. View logs:"
    echo "   sudo journalctl -u oteldemo-frontend -f"
    echo
    echo "Access points:"
    echo "  Frontend: http://localhost:3000"
    echo "  Load Generator: http://localhost:8090"
    echo "  Coralogix Agent Health: http://localhost:13133"
}

main() {
    log_info "Starting Demo Services Setup"
    
    check_root
    copy_source_code
    setup_frontend
    setup_cart
    setup_checkout
    setup_currency
    setup_email
    setup_payment
    setup_product_catalog
    setup_quote
    setup_recommendation
    setup_shipping
    setup_load_generator
    create_startup_script
    show_next_steps
}

# Run main function
main "$@"
