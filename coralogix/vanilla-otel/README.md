# OpenTelemetry Demo - Host Setup

Minimal setup to run OpenTelemetry demo services directly on Ubuntu as systemd services.

## Quick Start

```bash
# Install everything
sudo ./install.sh

# Build services
sudo ./build-services.sh

# Start all services
sudo ./quick-start.sh start

# Check status
sudo ./quick-start.sh status
```

## Access URLs

- **Frontend**: http://localhost:3000
- **Jaeger UI**: http://localhost:16686
- **Load Generator**: http://localhost:8089

## Service Management

```bash
# Start/stop all
sudo ./quick-start.sh start|stop|restart

# Individual services
sudo systemctl start|stop|restart oteldemo-frontend
sudo systemctl start|stop|restart otel-collector

# View logs
sudo journalctl -u otel-collector -f
sudo journalctl -u oteldemo-frontend -f
```

## Testing

```bash
# Test on VM
sudo ./test-vm.sh

# Local validation
make test-all
```
