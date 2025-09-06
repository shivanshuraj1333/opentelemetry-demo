# OpenTelemetry Demo - Vanilla Host Setup Guide

This guide provides step-by-step instructions for setting up the OpenTelemetry demo on a host system using systemd services.

## Prerequisites

### System Requirements
- Ubuntu 20.04+ (or compatible Linux distribution)
- Root or sudo access
- At least 4GB RAM
- At least 10GB free disk space

### Required Software
- Docker (for building service images)
- Node.js 16+
- Python 3.8+
- .NET 6.0 SDK
- Go 1.19+
- Rust 1.60+
- Java 11+
- PHP 8.0+
- C++ build tools (gcc, cmake)

## Installation Steps

### 1. Clone the Repository

```bash
git clone https://github.com/open-telemetry/opentelemetry-demo.git
cd opentelemetry-demo/coralogix/vanilla-otel
```

### 2. Run the Installation Script

```bash
sudo ./install.sh
```

This script will:
- Install all required dependencies
- Download OpenTelemetry Collector and Jaeger
- Create necessary users and directories
- Install systemd service files
- Set up PostgreSQL database

### 3. Build the Demo Services

```bash
sudo ./build-services.sh
```

This script will:
- Build all demo services from source
- Install them to `/opt/oteldemo/`
- Set proper permissions

### 4. Start the Services

```bash
sudo ./quick-start.sh start
```

Or start services individually:

```bash
# Start infrastructure services
sudo systemctl start postgresql redis-server kafka zookeeper otel-collector jaeger

# Start demo services
sudo systemctl start oteldemo-frontend oteldemo-cart oteldemo-checkout
```

## Service Management

### Starting Services

```bash
# Start all services
sudo ./quick-start.sh start

# Start specific service
sudo systemctl start oteldemo-frontend

# Start multiple services
sudo systemctl start oteldemo-frontend oteldemo-cart oteldemo-checkout
```

### Stopping Services

```bash
# Stop all services
sudo ./quick-start.sh stop

# Stop specific service
sudo systemctl stop oteldemo-frontend

# Stop all demo services
sudo systemctl stop oteldemo-*
```

### Checking Status

```bash
# Check all services
sudo ./quick-start.sh status

# Check specific service
sudo systemctl status oteldemo-frontend

# Check service logs
sudo journalctl -u oteldemo-frontend -f
```

### Enabling Auto-Start

```bash
# Enable specific service
sudo systemctl enable oteldemo-frontend

# Enable all demo services
sudo systemctl enable oteldemo-*
```

## Configuration

### Environment Variables

Edit `/opt/oteldemo/.env` to customize:

```bash
# OpenTelemetry Configuration
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
OTEL_SERVICE_NAME=your-service-name

# Service Ports
FRONTEND_PORT=3000
CART_PORT=8081
CHECKOUT_PORT=8082

# Database Configuration
DB_CONNECTION_STRING=Host=localhost;Username=root;Password=otel;Database=otel
```

### Collector Configuration

Edit `/etc/otelcol/otel-collector.yaml` to modify:
- Receivers (data sources)
- Processors (data processing)
- Exporters (data destinations)
- Service pipelines

### Service Configuration

Edit systemd service files in `/etc/systemd/system/` to modify:
- Environment variables
- Resource limits
- Startup dependencies
- Working directories

## Troubleshooting

### Common Issues

#### 1. Service Won't Start

```bash
# Check service status
sudo systemctl status service-name

# Check logs
sudo journalctl -u service-name -f

# Check dependencies
systemctl list-dependencies service-name
```

#### 2. Port Conflicts

```bash
# Check port usage
netstat -tlnp | grep -E ":(3000|8080|4317|4318)"

# Stop conflicting services
sudo systemctl stop conflicting-service
```

#### 3. Permission Issues

```bash
# Check file ownership
ls -la /opt/oteldemo/

# Fix ownership
sudo chown -R oteldemo:oteldemo /opt/oteldemo/
```

#### 4. Database Connection Issues

```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Check database
sudo -u postgres psql -c "SELECT 1;"

# Restart PostgreSQL
sudo systemctl restart postgresql
```

### Log Analysis

#### View All Logs

```bash
# All demo services
sudo journalctl -u "oteldemo-*" -f

# Specific service
sudo journalctl -u oteldemo-frontend -f

# Infrastructure services
sudo journalctl -u postgresql -u redis-server -u kafka -f
```

#### Log Filtering

```bash
# Error logs only
sudo journalctl -u oteldemo-frontend -p err

# Recent logs
sudo journalctl -u oteldemo-frontend --since "1 hour ago"

# Logs with specific pattern
sudo journalctl -u oteldemo-frontend | grep "ERROR"
```

## Performance Tuning

### Memory Limits

Edit systemd service files to adjust memory limits:

```ini
[Service]
MemoryMax=1G  # Increase for high-volume environments
```

### CPU Limits

```ini
[Service]
CPUQuota=50%  # Limit CPU usage
```

### Collector Tuning

Edit `/etc/otelcol/otel-collector.yaml`:

```yaml
processors:
  batch:
    send_batch_max_size: 4096  # Increase batch size
    timeout: 2s                # Increase timeout
  memory_limiter:
    limit_percentage: 80       # Adjust memory limit
```

## Monitoring

### Health Checks

```bash
# Collector health
curl http://localhost:13133

# Jaeger health
curl http://localhost:16686

# Frontend health
curl http://localhost:3000
```

### Metrics

- **Jaeger UI**: http://localhost:16686
- **Collector Metrics**: http://localhost:13133/metrics
- **Service Metrics**: Available through OpenTelemetry

### Logs

- **Systemd Journal**: `journalctl -u service-name`
- **Service Logs**: `/var/log/` (if configured)

## Security Considerations

### Service Users

- Services run as `oteldemo` user with minimal privileges
- No shell access for service users
- Restricted file system access

### Network Security

- Only necessary ports are exposed
- Services bind to localhost by default
- No external network access required

### File Permissions

- Configuration files are read-only for service users
- Log files have appropriate permissions
- Sensitive data is not logged

## Backup and Recovery

### Configuration Backup

```bash
# Backup configurations
sudo tar -czf otel-demo-config-backup.tar.gz /etc/otelcol/ /etc/systemd/system/oteldemo-*.service

# Backup service data
sudo tar -czf otel-demo-data-backup.tar.gz /opt/oteldemo/
```

### Recovery

```bash
# Restore configurations
sudo tar -xzf otel-demo-config-backup.tar.gz -C /

# Restore service data
sudo tar -xzf otel-demo-data-backup.tar.gz -C /

# Restart services
sudo systemctl daemon-reload
sudo systemctl restart oteldemo-*
```

## Maintenance

### Regular Tasks

1. **Monitor Service Health**
   ```bash
   sudo ./quick-start.sh status
   ```

2. **Check Logs for Errors**
   ```bash
   sudo journalctl -u "oteldemo-*" --since "1 day ago" | grep ERROR
   ```

3. **Update Services**
   ```bash
   sudo ./build-services.sh
   sudo systemctl restart oteldemo-*
   ```

4. **Clean Up Logs**
   ```bash
   sudo journalctl --vacuum-time=7d
   ```

### Updates

1. **Update Dependencies**
   ```bash
   sudo apt update && sudo apt upgrade
   ```

2. **Update Services**
   ```bash
   git pull
   sudo ./build-services.sh
   ```

3. **Restart Services**
   ```bash
   sudo ./quick-start.sh restart
   ```

## Support

### Getting Help

1. Check the logs for error messages
2. Verify configuration syntax
3. Ensure all dependencies are installed
4. Check service dependencies and startup order

### Useful Commands

```bash
# Service management
sudo systemctl start|stop|restart|status service-name

# Log viewing
sudo journalctl -u service-name -f

# Configuration editing
sudo nano /etc/systemd/system/service-name.service

# Permission fixing
sudo chown -R oteldemo:oteldemo /opt/oteldemo/
```

## License

This configuration is provided under the same license as the OpenTelemetry Demo project.
