# OpenTelemetry Demo - Testing Guide

This guide explains how to test the vanilla OpenTelemetry setup in different environments.

## 🧪 Testing Options

### Option 1: Dev Container (Recommended for Development)

**Best for:** Development, script testing, configuration validation

**Pros:**
- Easy to set up and iterate
- Tests installation scripts and configurations
- Validates file structures and syntax
- Good for development workflow

**Cons:**
- Cannot test actual systemd service management
- Architecture mismatch (ARM Mac vs AMD64 VM)
- Limited host system integration testing

**Setup:**
```bash
# Open in VS Code with Dev Containers extension
code .

# Or use Docker directly
docker run -it --rm -v $(pwd):/workspace ubuntu:22.04 bash
```

### Option 2: VM Testing (Recommended for Production)

**Best for:** Production testing, full system validation

**Pros:**
- Tests actual systemd service management
- Real host system integration
- Correct architecture (AMD64)
- Complete end-to-end testing

**Cons:**
- Requires access to Ubuntu VM
- More time-consuming setup
- Harder to iterate quickly

**Setup:**
```bash
# Copy files to your Ubuntu VM
scp -r . user@your-vm:/opt/otel-demo/

# SSH into VM
ssh user@your-vm

# Run comprehensive test
cd /opt/otel-demo
sudo ./test-vm.sh
```

## 🚀 Quick Testing Commands

### Local Development Testing (Mac)

```bash
# Test script syntax and configurations
make test-all

# Test individual components
make test-scripts    # Test bash script syntax
make test-configs    # Validate YAML and config files
make test-services   # Check systemd service files
```

### VM Testing (Ubuntu)

```bash
# Run comprehensive test suite
sudo ./test-vm.sh

# Manual testing steps
sudo ./install.sh
sudo ./build-services.sh
sudo ./quick-start.sh start
sudo ./quick-start.sh status
```

## 📋 Test Coverage

### Dev Container Tests
- ✅ Script syntax validation
- ✅ YAML configuration validation
- ✅ Systemd service file structure
- ✅ Environment variable validation
- ✅ SQL syntax validation
- ✅ Makefile target validation

### VM Tests
- ✅ Prerequisites check (OS, memory, disk)
- ✅ Installation process
- ✅ Service building
- ✅ Infrastructure service startup
- ✅ Demo service startup
- ✅ Service connectivity
- ✅ Observability features
- ✅ End-to-end functionality

## 🔧 Dev Container Setup

The dev container includes:
- Ubuntu 22.04 base image
- All required development tools (Node.js, Python, Go, .NET, Rust, Java, PHP)
- OpenTelemetry Collector and Jaeger
- VS Code extensions for development
- Pre-configured environment

**Files:**
- `.devcontainer/devcontainer.json` - Dev container configuration
- `.devcontainer/setup-devcontainer.sh` - Setup script

## 🖥️ VM Test Script

The VM test script (`test-vm.sh`) provides comprehensive testing:

**Test Phases:**
1. **Prerequisites** - OS, memory, disk space
2. **Installation** - Run install script
3. **Service Building** - Build all demo services
4. **Infrastructure Services** - Start PostgreSQL, Redis, Kafka, etc.
5. **Demo Services** - Start all demo microservices
6. **Connectivity** - Test HTTP endpoints
7. **Observability** - Test OTLP endpoints and metrics

**Output:**
- Real-time test progress
- Detailed test report (`/tmp/otel-demo-test-report.txt`)
- Service status logs
- Error diagnostics

## 🐛 Troubleshooting

### Dev Container Issues

```bash
# Rebuild container
docker-compose down && docker-compose up --build

# Check container logs
docker logs <container-id>

# Access container shell
docker exec -it <container-id> bash
```

### VM Test Issues

```bash
# Check test logs
cat /tmp/otel-demo-test.log

# Check service status
sudo systemctl status otel-collector
sudo systemctl status oteldemo-*

# Check service logs
sudo journalctl -u otel-collector -f
sudo journalctl -u oteldemo-frontend -f
```

### Common Issues

1. **Permission Denied**
   ```bash
   sudo chmod +x *.sh
   sudo chown -R oteldemo:oteldemo /opt/oteldemo/
   ```

2. **Service Won't Start**
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart service-name
   ```

3. **Port Conflicts**
   ```bash
   sudo netstat -tlnp | grep :3000
   sudo systemctl stop conflicting-service
   ```

## 📊 Test Results

### Expected Dev Container Results
```
Testing script syntax...
  build-services.sh: OK
  install.sh: OK
  quick-start.sh: OK
  test-vm.sh: OK

Testing configuration files...
  otel-collector.yaml: OK
  env.vanilla: OK
  init.sql: OK

Testing systemd service files...
  jaeger.service: OK
  kafka.service: OK
  otel-collector.service: OK
  oteldemo-frontend.service: OK
  ...
```

### Expected VM Test Results
```
[SUCCESS] Prerequisites check completed
[SUCCESS] Installation script completed successfully
[SUCCESS] Service building completed successfully
[SUCCESS] All infrastructure services are running
[SUCCESS] All demo services are running
[SUCCESS] All services are responding to HTTP requests
[SUCCESS] Observability features tested
[SUCCESS] All tests passed! OpenTelemetry Demo is working correctly.
```

## 🎯 Recommendation

**For your use case (ARM Mac → AMD64 Ubuntu VM):**

1. **Use Dev Container** for:
   - Initial development and testing
   - Script validation
   - Configuration testing
   - Quick iterations

2. **Use VM Testing** for:
   - Final validation
   - Production readiness testing
   - Full system integration testing
   - Performance testing

This hybrid approach gives you the best of both worlds: fast development iteration with the dev container, and comprehensive validation with the VM test script.
