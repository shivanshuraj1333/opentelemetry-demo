#!/bin/bash

# OpenTelemetry Demo - Setup Demo Services
# This script sets up minimal demo services for testing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
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

setup_frontend() {
    log_info "Setting up Frontend service..."
    
    mkdir -p "$SERVICE_DIR/frontend"
    
    # Create a simple HTTP server
    cat > "$SERVICE_DIR/frontend/server.js" << 'EOF'
const http = require('http');
const port = process.env.PORT || 3000;

const server = http.createServer((req, res) => {
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(`
        <!DOCTYPE html>
        <html>
        <head>
            <title>OpenTelemetry Demo - Frontend</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 40px; }
                .container { max-width: 800px; margin: 0 auto; }
                .header { background: #4CAF50; color: white; padding: 20px; border-radius: 5px; }
                .content { padding: 20px; }
                .service { background: #f5f5f5; padding: 15px; margin: 10px 0; border-radius: 5px; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>🚀 OpenTelemetry Demo - Frontend</h1>
                    <p>Native Host Deployment</p>
                </div>
                <div class="content">
                    <h2>Services Status</h2>
                    <div class="service">
                        <h3>Frontend</h3>
                        <p>✅ Running on port ${port}</p>
                    </div>
                    <div class="service">
                        <h3>Jaeger UI</h3>
                        <p><a href="http://localhost:16686" target="_blank">http://localhost:16686</a></p>
                    </div>
                    <div class="service">
                        <h3>Load Generator</h3>
                        <p><a href="http://localhost:8089" target="_blank">http://localhost:8089</a></p>
                    </div>
                    <div class="service">
                        <h3>OpenTelemetry Collector</h3>
                        <p><a href="http://localhost:13133" target="_blank">http://localhost:13133</a></p>
                    </div>
                </div>
            </div>
        </body>
        </html>
    `);
});

server.listen(port, '0.0.0.0', () => {
    console.log(`Frontend server running on port ${port}`);
});
EOF

    # Create package.json
    cat > "$SERVICE_DIR/frontend/package.json" << 'EOF'
{
  "name": "frontend",
  "version": "1.0.0",
  "description": "OpenTelemetry Demo Frontend",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  }
}
EOF

    # Install dependencies
    cd "$SERVICE_DIR/frontend"
    npm install --production
    
    chown -R "$SERVICE_USER:$SERVICE_GROUP" "$SERVICE_DIR/frontend"
    log_success "Frontend service setup complete"
}

setup_cart() {
    log_info "Setting up Cart service..."
    
    mkdir -p "$SERVICE_DIR/cart"
    
    # Create a simple HTTP server
    cat > "$SERVICE_DIR/cart/server.js" << 'EOF'
const http = require('http');
const port = process.env.PORT || 8081;

const server = http.createServer((req, res) => {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
        service: 'cart',
        status: 'running',
        port: port,
        message: 'Cart service is running'
    }));
});

server.listen(port, '0.0.0.0', () => {
    console.log(`Cart service running on port ${port}`);
});
EOF

    # Create package.json
    cat > "$SERVICE_DIR/cart/package.json" << 'EOF'
{
  "name": "cart",
  "version": "1.0.0",
  "description": "OpenTelemetry Demo Cart Service",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  }
}
EOF

    # Install dependencies
    cd "$SERVICE_DIR/cart"
    npm install --production
    
    chown -R "$SERVICE_USER:$SERVICE_GROUP" "$SERVICE_DIR/cart"
    log_success "Cart service setup complete"
}

setup_checkout() {
    log_info "Setting up Checkout service..."
    
    mkdir -p "$SERVICE_DIR/checkout"
    
    # Create a simple Go server
    cat > "$SERVICE_DIR/checkout/main.go" << 'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "log"
    "net/http"
    "os"
)

type Response struct {
    Service string `json:"service"`
    Status  string `json:"status"`
    Port    string `json:"port"`
    Message string `json:"message"`
}

func handler(w http.ResponseWriter, r *http.Request) {
    port := os.Getenv("PORT")
    if port == "" {
        port = "8082"
    }
    
    response := Response{
        Service: "checkout",
        Status:  "running",
        Port:    port,
        Message: "Checkout service is running",
    }
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(response)
}

func main() {
    port := os.Getenv("PORT")
    if port == "" {
        port = "8082"
    }
    
    http.HandleFunc("/", handler)
    fmt.Printf("Checkout service running on port %s\n", port)
    log.Fatal(http.ListenAndServe(":"+port, nil))
}
EOF

    # Create go.mod
    cat > "$SERVICE_DIR/checkout/go.mod" << 'EOF'
module checkout

go 1.21
EOF

    # Build the service
    cd "$SERVICE_DIR/checkout"
    go mod tidy
    go build -o checkout main.go
    
    chown -R "$SERVICE_USER:$SERVICE_GROUP" "$SERVICE_DIR/checkout"
    log_success "Checkout service setup complete"
}

setup_currency() {
    log_info "Setting up Currency service..."
    
    mkdir -p "$SERVICE_DIR/currency"
    
    # Create a simple C++ server
    cat > "$SERVICE_DIR/currency/main.cpp" << 'EOF'
#include <iostream>
#include <string>
#include <cstdlib>

int main() {
    std::string port = std::getenv("PORT");
    if (port.empty()) {
        port = "8083";
    }
    
    std::cout << "Currency service running on port " << port << std::endl;
    std::cout << "Service: currency" << std::endl;
    std::cout << "Status: running" << std::endl;
    
    // Keep running
    while (true) {
        std::this_thread::sleep_for(std::chrono::seconds(1));
    }
    
    return 0;
}
EOF

    # Create a simple shell script instead
    cat > "$SERVICE_DIR/currency/currency.sh" << 'EOF'
#!/bin/bash
PORT=${PORT:-8083}
echo "Currency service running on port $PORT"
echo "Service: currency"
echo "Status: running"
sleep infinity
EOF

    chmod +x "$SERVICE_DIR/currency/currency.sh"
    chown -R "$SERVICE_USER:$SERVICE_GROUP" "$SERVICE_DIR/currency"
    log_success "Currency service setup complete"
}

setup_payment() {
    log_info "Setting up Payment service..."
    
    mkdir -p "$SERVICE_DIR/payment"
    
    # Create a simple Node.js server
    cat > "$SERVICE_DIR/payment/server.js" << 'EOF'
const http = require('http');
const port = process.env.PORT || 8084;

const server = http.createServer((req, res) => {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
        service: 'payment',
        status: 'running',
        port: port,
        message: 'Payment service is running'
    }));
});

server.listen(port, '0.0.0.0', () => {
    console.log(`Payment service running on port ${port}`);
});
EOF

    # Create package.json
    cat > "$SERVICE_DIR/payment/package.json" << 'EOF'
{
  "name": "payment",
  "version": "1.0.0",
  "description": "OpenTelemetry Demo Payment Service",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  }
}
EOF

    # Install dependencies
    cd "$SERVICE_DIR/payment"
    npm install --production
    
    chown -R "$SERVICE_USER:$SERVICE_GROUP" "$SERVICE_DIR/payment"
    log_success "Payment service setup complete"
}

setup_product_catalog() {
    log_info "Setting up Product Catalog service..."
    
    mkdir -p "$SERVICE_DIR/product-catalog"
    
    # Create a simple Go server
    cat > "$SERVICE_DIR/product-catalog/main.go" << 'EOF'
package main

import (
    "encoding/json"
    "fmt"
    "log"
    "net/http"
    "os"
)

type Response struct {
    Service string `json:"service"`
    Status  string `json:"status"`
    Port    string `json:"port"`
    Message string `json:"message"`
}

func handler(w http.ResponseWriter, r *http.Request) {
    port := os.Getenv("PORT")
    if port == "" {
        port = "8086"
    }
    
    response := Response{
        Service: "product-catalog",
        Status:  "running",
        Port:    port,
        Message: "Product Catalog service is running",
    }
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(response)
}

func main() {
    port := os.Getenv("PORT")
    if port == "" {
        port = "8086"
    }
    
    http.HandleFunc("/", handler)
    fmt.Printf("Product Catalog service running on port %s\n", port)
    log.Fatal(http.ListenAndServe(":"+port, nil))
}
EOF

    # Create go.mod
    cat > "$SERVICE_DIR/product-catalog/go.mod" << 'EOF'
module product-catalog

go 1.21
EOF

    # Build the service
    cd "$SERVICE_DIR/product-catalog"
    go mod tidy
    go build -o product-catalog main.go
    
    chown -R "$SERVICE_USER:$SERVICE_GROUP" "$SERVICE_DIR/product-catalog"
    log_success "Product Catalog service setup complete"
}

setup_load_generator() {
    log_info "Setting up Load Generator service..."
    
    mkdir -p "$SERVICE_DIR/load-generator"
    
    # Create a simple Python server
    cat > "$SERVICE_DIR/load-generator/server.py" << 'EOF'
#!/usr/bin/env python3
import os
import time
import threading
import requests
from http.server import HTTPServer, BaseHTTPRequestHandler
import json

PORT = int(os.environ.get('PORT', 8089))

class LoadGeneratorHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()
        
        response = {
            "service": "load-generator",
            "status": "running",
            "port": str(PORT),
            "message": "Load Generator service is running"
        }
        
        self.wfile.write(json.dumps(response).encode())

def generate_load():
    """Generate load by making requests to other services"""
    while True:
        try:
            # Make requests to various services
            services = [
                "http://localhost:3000",
                "http://localhost:8081",
                "http://localhost:8082",
                "http://localhost:8083",
                "http://localhost:8084",
                "http://localhost:8086"
            ]
            
            for service in services:
                try:
                    response = requests.get(service, timeout=1)
                    print(f"Load generated to {service}: {response.status_code}")
                except:
                    pass  # Ignore errors for load generation
                    
        except Exception as e:
            print(f"Load generation error: {e}")
        
        time.sleep(1)

if __name__ == "__main__":
    # Start load generation in background
    load_thread = threading.Thread(target=generate_load, daemon=True)
    load_thread.start()
    
    # Start HTTP server
    server = HTTPServer(('0.0.0.0', PORT), LoadGeneratorHandler)
    print(f"Load Generator service running on port {PORT}")
    server.serve_forever()
EOF

    # Create requirements.txt
    cat > "$SERVICE_DIR/load-generator/requirements.txt" << 'EOF'
requests==2.31.0
EOF

    # Install dependencies
    cd "$SERVICE_DIR/load-generator"
    pip3 install -r requirements.txt
    
    chmod +x "$SERVICE_DIR/load-generator/server.py"
    chown -R "$SERVICE_USER:$SERVICE_GROUP" "$SERVICE_DIR/load-generator"
    log_success "Load Generator service setup complete"
}

main() {
    log_info "Setting up OpenTelemetry Demo Services"
    
    check_root
    
    setup_frontend
    setup_cart
    setup_checkout
    setup_currency
    setup_payment
    setup_product_catalog
    setup_load_generator
    
    log_success "All demo services setup complete!"
    log_info "Services are ready to be started with: sudo ./quick-start.sh start"
}

main "$@"
