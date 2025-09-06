# Ubuntu VM Setup Checklist

## ✅ Pre-Installation Checklist

### System Requirements
- [ ] Ubuntu 20.04+ (tested on 24.04)
- [ ] At least 4GB RAM
- [ ] At least 10GB free disk space
- [ ] Root/sudo access
- [ ] Internet connectivity

### Clean VM Setup
- [ ] Fresh Ubuntu installation
- [ ] No previous Docker/Kubernetes installations
- [ ] No conflicting package repositories
- [ ] System updated: `sudo apt update && sudo apt upgrade`

## 🚀 Installation Steps

### 1. Copy Files to VM
```bash
# Copy the vanilla-otel directory to your VM
scp -r . user@your-vm:/opt/otel-demo/
```

### 2. Run Installation
```bash
# SSH into your VM
ssh user@your-vm

# Navigate to the directory
cd /opt/otel-demo

# Make scripts executable
sudo chmod +x *.sh

# Clean up any previous installation (if needed)
sudo ./cleanup.sh

# Run comprehensive test (recommended)
sudo ./test-vm.sh
```

### 3. Manual Installation (if needed)
```bash
# Install everything
sudo ./install.sh

# Setup demo services
sudo ./setup-demo.sh

# Start services
sudo ./quick-start.sh start
```

## ✅ Post-Installation Verification

### Check Services
```bash
# Infrastructure services
sudo systemctl status postgresql redis-server kafka zookeeper otel-collector jaeger

# Demo services
sudo systemctl status oteldemo-*

# All services at once
sudo ./quick-start.sh status
```

### Test Connectivity
```bash
# OpenTelemetry Collector
curl http://localhost:13133

# Jaeger UI
curl http://localhost:16686

# Frontend
curl http://localhost:3000

# Load Generator
curl http://localhost:8089
```

### Access URLs
- **Frontend**: http://localhost:3000
- **Jaeger UI**: http://localhost:16686
- **Load Generator**: http://localhost:8089

## 🔧 Troubleshooting

### Common Issues
1. **Permission Denied**: `sudo chmod +x *.sh`
2. **Service Won't Start**: `sudo systemctl daemon-reload`
3. **Port Conflicts**: `sudo netstat -tlnp | grep :3000`
4. **Dependencies Missing**: `sudo apt update && sudo apt install -f`

### Logs
```bash
# Service logs
sudo journalctl -u otel-collector -f
sudo journalctl -u oteldemo-frontend -f

# All demo services
sudo journalctl -u "oteldemo-*" -f
```

### Reset Everything
```bash
# Stop all services
sudo ./quick-start.sh stop

# Clean up
sudo make clean

# Reinstall
sudo ./install.sh
sudo ./build-services.sh
sudo ./quick-start.sh start
```

## 📋 Dependencies Installed

### System Packages
- postgresql postgresql-contrib
- redis-server
- openjdk-11-jdk
- nodejs npm
- python3 python3-pip python3-venv
- dotnet-sdk-6.0
- golang-go
- php-cli php-curl php-json
- build-essential cmake pkg-config libssl-dev
- default-jre

### Downloaded Binaries
- OpenTelemetry Collector (0.131.1)
- Jaeger (1.51.0)
- Apache Kafka (3.6.1)

### Created Users
- otelcol (OpenTelemetry Collector)
- oteldemo (Demo services)
- jaeger (Jaeger)
- kafka (Kafka)
- zookeeper (Zookeeper)

## ✅ Success Criteria

The setup is successful when:
- [ ] All services are running (`systemctl status` shows active)
- [ ] Frontend loads at http://localhost:3000
- [ ] Jaeger UI loads at http://localhost:16686
- [ ] Load Generator loads at http://localhost:8089
- [ ] No error messages in logs
- [ ] Services restart automatically on reboot
