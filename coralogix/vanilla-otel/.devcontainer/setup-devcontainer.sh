#!/bin/bash

# Dev Container Setup Script for OpenTelemetry Demo
# This script sets up the development environment

set -e

echo "🚀 Setting up OpenTelemetry Demo development environment..."

# Update package lists
sudo apt-get update

# Install additional dependencies
sudo apt-get install -y \
    wget \
    curl \
    unzip \
    git \
    build-essential \
    cmake \
    pkg-config \
    libssl-dev \
    postgresql-client \
    redis-tools \
    netcat-openbsd \
    jq \
    yamllint \
    systemd-container

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install OpenTelemetry Collector
OTELCOL_VERSION="0.131.1"
ARCH="amd64"
wget -O /tmp/otelcol-contrib.tar.gz "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${OTELCOL_VERSION}/otelcol-contrib_${OTELCOL_VERSION}_linux_${ARCH}.tar.gz"
tar -xzf /tmp/otelcol-contrib.tar.gz -C /tmp/
sudo cp /tmp/otelcol-contrib /usr/local/bin/
sudo chmod +x /usr/local/bin/otelcol-contrib
rm -f /tmp/otelcol-contrib.tar.gz /tmp/otelcol-contrib

# Install Jaeger
JAEGER_VERSION="1.51.0"
wget -O /tmp/jaeger.tar.gz "https://github.com/jaegertracing/jaeger/releases/download/v${JAEGER_VERSION}/jaeger-${JAEGER_VERSION}-linux-amd64.tar.gz"
tar -xzf /tmp/jaeger.tar.gz -C /tmp/
sudo cp /tmp/jaeger-${JAEGER_VERSION}-linux-amd64/jaeger-all-in-one /usr/local/bin/
sudo chmod +x /usr/local/bin/jaeger-all-in-one
rm -rf /tmp/jaeger.tar.gz /tmp/jaeger-${JAEGER_VERSION}-linux-amd64

# Create test users
sudo useradd --system --no-create-home --shell /bin/false otelcol || true
sudo useradd --system --no-create-home --shell /bin/false oteldemo || true
sudo useradd --system --no-create-home --shell /bin/false jaeger || true

# Create test directories
sudo mkdir -p /etc/otelcol
sudo mkdir -p /var/lib/otelcol
sudo mkdir -p /var/lib/jaeger
sudo mkdir -p /opt/oteldemo

# Set ownership
sudo chown -R otelcol:otelcol /etc/otelcol /var/lib/otelcol
sudo chown -R jaeger:jaeger /var/lib/jaeger
sudo chown -R oteldemo:oteldemo /opt/oteldemo

# Copy configuration files
sudo cp otel-collector.yaml /etc/otelcol/
sudo cp init.sql /etc/otelcol/

# Install systemd service files for testing
sudo cp services/*.service /etc/systemd/system/

# Reload systemd
sudo systemctl daemon-reload

echo "✅ Development environment setup complete!"
echo ""
echo "Available commands:"
echo "  make test-scripts    - Test installation scripts"
echo "  make test-configs    - Validate configuration files"
echo "  make test-services   - Test service file syntax"
echo "  make test-all        - Run all tests"
echo ""
echo "Note: This is a development environment. For production testing,"
echo "use the test script on your actual Ubuntu VM."
