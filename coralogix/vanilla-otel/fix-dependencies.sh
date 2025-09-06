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

log_info "Fixing package dependencies..."

# Stop any running services
systemctl stop docker || true
systemctl stop containerd || true

# Remove conflicting packages
log_info "Removing conflicting packages..."
apt-get remove -y containerd npm nodejs || true
apt-get autoremove -y

# Clean package cache
log_info "Cleaning package cache..."
apt-get clean
apt-get autoclean

# Fix broken packages
log_info "Fixing broken packages..."
dpkg --configure -a || true
apt-get install -f -y

# Update package lists
log_info "Updating package lists..."
apt-get update

# Install basic tools
log_info "Installing basic tools..."
apt-get install -y \
    curl \
    wget \
    gnupg \
    lsb-release \
    ca-certificates \
    software-properties-common

log_success "Dependencies fixed! You can now run ./install.sh"
