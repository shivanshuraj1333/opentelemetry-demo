# OpenTelemetry Demo - Vanilla Host Deployment

This directory contains a simplified setup to run the OpenTelemetry demo services directly on a host system as systemd services, without any vendor-specific configurations.

## Overview

This deployment provides:
- **OpenTelemetry Collector**: Standard collector configuration for observability
- **OpenTelemetry Demo Services**: E-commerce microservices demonstrating observability
- **Infrastructure Services**: PostgreSQL, Redis, Kafka for the demo
- **Systemd Services**: All services run as native systemd services

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Host System                              │
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐                    │
│  │ OpenTelemetry   │    │ Jaeger          │                    │
│  │ Collector       │    │ (Tracing UI)    │                    │
│  │ (systemd)       │    │ (systemd)       │                    │
│  └─────────────────┘    └─────────────────┘                    │
│           │                       │                            │
│           └───────────────────────┼────────────────────────────┘
│                                   │
│  ┌─────────────────────────────────┼────────────────────────────┐
│  │        Demo Services            │                            │
│  │  ┌─────────┐ ┌─────────┐ ┌─────┼─────┐ ┌─────────┐          │
│  │  │Frontend │ │  Cart   │ │Checkout│   │   ...    │          │
│  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘          │
│  └─────────────────────────────────────────────────────────────┘
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐
│  │        Infrastructure Services (systemd)                   │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐          │
│  │  │PostgreSQL│ │  Redis  │ │  Kafka  │ │Zookeeper│          │
│  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘          │
│  └─────────────────────────────────────────────────────────────┘
└─────────────────────────────────────────────────────────────────┘
```

## Prerequisites

- Ubuntu 20.04+ (or compatible Linux distribution)
- Root or sudo access
- Docker (for building demo service images)
- Node.js, Python, Java, .NET, Go, PHP, Rust (for running services natively)

## Quick Start

### 1. Install Dependencies

```bash
# Clone the repository
git clone https://github.com/open-telemetry/opentelemetry-demo.git
cd opentelemetry-demo/coralogix/vanilla-otel

# Run the installation script
sudo ./install.sh
```

### 2. Build Demo Services

```bash
# Build all demo service images
sudo ./build-services.sh
```

### 3. Start Services

```bash
# Start infrastructure services
sudo systemctl start postgresql redis kafka zookeeper

# Start OpenTelemetry collector
sudo systemctl start otel-collector

# Start demo services
sudo systemctl start oteldemo-frontend oteldemo-cart oteldemo-checkout
# ... (start other services as needed)
```

### 4. Access the Demo

- **Frontend**: http://localhost:3000
- **Jaeger UI**: http://localhost:16686
- **Load Generator**: http://localhost:8089
- **Collector Health**: http://localhost:13133

## Configuration Files

### OpenTelemetry Collector (`otel-collector.yaml`)

The collector configuration includes:
- **Receivers**: OTLP, Jaeger, Zipkin, Prometheus, Host Metrics
- **Processors**: Batch, Memory Limiter, Resource Detection, Transformations
- **Exporters**: Jaeger, Prometheus, OpenSearch, Debug

### Systemd Services

Each service includes:
- Resource limits (memory, CPU)
- Environment variables
- Dependencies and startup order
- Logging to systemd journal

## Service Management

### Check Service Status

```bash
# Check all services
sudo systemctl status otel-collector oteldemo-frontend

# Check specific service
sudo systemctl status oteldemo-cart
```

### View Logs

```bash
# Service logs
sudo journalctl -u otel-collector -f
sudo journalctl -u oteldemo-frontend -f

# All demo service logs
sudo journalctl -u "oteldemo-*" -f
```

### Start/Stop Services

```bash
# Start a service
sudo systemctl start oteldemo-frontend

# Stop a service
sudo systemctl stop oteldemo-frontend

# Restart a service
sudo systemctl restart oteldemo-frontend

# Enable auto-start
sudo systemctl enable oteldemo-frontend
```

## Troubleshooting

### Common Issues

1. **Service Won't Start**
   ```bash
   # Check service status
   sudo systemctl status service-name
   
   # Check logs
   sudo journalctl -u service-name -f
   ```

2. **Port Conflicts**
   ```bash
   # Check port usage
   netstat -tlnp | grep -E ":(3000|8080|4317|4318)"
   
   # Stop conflicting services
   sudo systemctl stop conflicting-service
   ```

3. **Dependencies Not Ready**
   ```bash
   # Check service dependencies
   systemctl list-dependencies oteldemo-frontend
   
   # Start dependencies first
   sudo systemctl start postgresql redis kafka
   ```

## Customization

### Adding Custom Metrics

Edit the collector configuration to add custom metrics:

```yaml
receivers:
  prometheus:
    config:
      scrape_configs:
      - job_name: custom-metrics
        static_configs:
        - targets: ['localhost:9090']
```

### Modifying Service Configuration

Edit systemd service files to change:
- Environment variables
- Resource limits
- Startup dependencies
- Working directories

## Security Considerations

- Services run with minimal privileges
- Configuration files are read-only for service users
- Network access is limited to necessary ports only
- Resource limits prevent resource exhaustion

## Performance Tuning

### Memory Limits

Adjust memory limits in systemd service files:

```ini
[Service]
MemoryMax=1G  # Increase for high-volume environments
```

### Batch Processing

Tune batch processing in collector configuration:

```yaml
processors:
  batch:
    send_batch_max_size: 4096
    timeout: 2s
```

## Support

For issues and questions:
- Check the logs for error messages
- Verify configuration syntax
- Ensure all dependencies are installed
- Check service dependencies and startup order

## License

This configuration is provided under the same license as the OpenTelemetry Demo project.
