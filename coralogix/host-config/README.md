# OpenTelemetry Demo - Host Deployment with Coralogix

This directory contains configurations and scripts to deploy the OpenTelemetry demo directly on a host system with Coralogix agent and collector for observability.

## Overview

This deployment provides:
- **Coralogix Agent**: Collects logs, metrics, and traces from the host system
- **Coralogix Collector**: Aggregates and forwards telemetry data to Coralogix
- **OpenTelemetry Demo Services**: E-commerce microservices demonstrating observability
- **Infrastructure Services**: PostgreSQL, Redis, Kafka for the demo

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Host System                              │
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐                    │
│  │ Coralogix Agent │    │ Coralogix       │                    │
│  │ (systemd)       │    │ Collector       │                    │
│  │                 │    │ (systemd)       │                    │
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
│  │        Infrastructure Services (Docker)                    │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐          │
│  │  │PostgreSQL│ │  Redis  │ │  Kafka  │ │Zookeeper│          │
│  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘          │
│  └─────────────────────────────────────────────────────────────┘
└─────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
                          ┌─────────────────┐
                          │   Coralogix     │
                          │   Platform      │
                          └─────────────────┘
```

## Prerequisites

- Linux host (Ubuntu 20.04+, CentOS 7+, RHEL 7+, Amazon Linux 2+)
- Docker and Docker Compose
- Root or sudo access
- Coralogix private key

## Quick Start

### 1. Install Coralogix Agent and Collector

```bash
# Clone the repository
git clone https://github.com/open-telemetry/opentelemetry-demo.git
cd opentelemetry-demo/coralogix/host-config

# Run the installation script
sudo ./install.sh
```

### 2. Configure Coralogix

```bash
# Edit the environment file
sudo nano /etc/otelcol/coralogix.env

# Set your Coralogix private key
CORALOGIX_PRIVATE_KEY=your_private_key_here
```

### 3. Start Coralogix Services

```bash
# Start the services
sudo systemctl start coralogix-agent
sudo systemctl start coralogix-collector

# Enable auto-start
sudo systemctl enable coralogix-agent
sudo systemctl enable coralogix-collector

# Check status
sudo systemctl status coralogix-agent
sudo systemctl status coralogix-collector
```

### 4. Deploy Demo Services

```bash
# Copy environment file
cp env.host .env

# Edit configuration
nano .env

# Start infrastructure services
docker-compose -f docker-compose-host.yml up -d postgresql redis kafka zookeeper

# Start demo services
docker-compose -f docker-compose-host.yml up -d
```

### 5. Access the Demo

- **Frontend**: http://localhost:3000
- **Load Generator**: http://localhost:8089
- **Coralogix Agent Health**: http://localhost:13133
- **Coralogix Collector Health**: http://localhost:13133

## Configuration Files

### Coralogix Agent (`agent.yaml`)

The agent configuration includes:
- **Receivers**: OTLP, Jaeger, Zipkin, StatsD, Prometheus, Host Metrics, File Logs
- **Processors**: Batch, Memory Limiter, Resource Detection, Sampling, Transformations
- **Exporters**: Coralogix (logs, metrics, traces), Resource Catalog
- **Connectors**: Span Metrics, Forwarding

Key features:
- Collects host system metrics and logs
- Processes OpenTelemetry data from demo services
- Applies sampling and transformations
- Forwards data to Coralogix collector

### Coralogix Collector (`collector.yaml`)

The collector configuration includes:
- **Receivers**: OTLP, Prometheus
- **Processors**: Batch, Memory Limiter, Resource Detection, Transformations
- **Exporters**: Coralogix (logs, metrics, traces), Resource Catalog

Key features:
- Aggregates data from multiple sources
- Applies final processing and transformations
- Exports to Coralogix platform

### Systemd Services

- **`coralogix-agent.service`**: Runs the agent as a system service
- **`coralogix-collector.service`**: Runs the collector as a system service

Both services include:
- Resource limits (memory, CPU)
- Security restrictions
- Auto-restart on failure
- Logging to systemd journal

## Monitoring and Troubleshooting

### Check Service Status

```bash
# Check all services
sudo systemctl status coralogix-agent coralogix-collector

# Check demo services
docker-compose -f docker-compose-host.yml ps
```

### View Logs

```bash
# Coralogix services
sudo journalctl -u coralogix-agent -f
sudo journalctl -u coralogix-collector -f

# Demo services
docker-compose -f docker-compose-host.yml logs -f
```

### Health Checks

```bash
# Agent health
curl http://localhost:13133

# Collector health
curl http://localhost:13133

# Prometheus metrics
curl http://localhost:8888/metrics
```

### Common Issues

1. **Permission Denied**: Ensure the `otelcol` user has proper permissions
2. **Port Conflicts**: Check if ports 4317, 4318, 13133 are available
3. **Configuration Errors**: Validate YAML syntax in config files
4. **Memory Issues**: Adjust memory limits in systemd service files

## Advanced Configuration

### Custom Resource Attributes

Edit the configuration files to add custom resource attributes:

```yaml
processors:
  resource/metadata:
    attributes:
    - action: upsert
      key: custom.attribute
      value: custom-value
```

### Sampling Configuration

Adjust sampling rates in the agent configuration:

```yaml
processors:
  probabilistic_sampler:
    mode: proportional
    sampling_percentage: 10  # 10% sampling
```

### Log Collection

Configure additional log sources:

```yaml
receivers:
  filelog:
    include:
    - /var/log/application/*.log
    - /var/log/nginx/*.log
```

## Security Considerations

- The `otelcol` user runs with minimal privileges
- Configuration files are read-only for the service user
- Private keys are stored in environment files with restricted permissions
- Network access is limited to necessary ports only

## Performance Tuning

### Memory Limits

Adjust memory limits in systemd service files:

```ini
[Service]
MemoryMax=1G  # Increase for high-volume environments
```

### Batch Processing

Tune batch processing for better performance:

```yaml
processors:
  batch:
    send_batch_max_size: 4096  # Increase batch size
    timeout: 2s                # Increase timeout
```

## Integration with Coralogix

### Dashboards

Create custom dashboards in Coralogix using the collected metrics:
- System metrics (CPU, memory, disk)
- Application metrics (request rates, response times)
- Business metrics (orders, revenue)

### Alerts

Set up alerts based on:
- Error rates and response times
- System resource utilization
- Application-specific metrics

### Log Analysis

Use Coralogix's log analysis features:
- Search and filter logs
- Create log-based alerts
- Correlate logs with metrics and traces

## Support

For issues and questions:
- Check the logs for error messages
- Verify configuration syntax
- Ensure all dependencies are installed
- Contact Coralogix support for platform-specific issues

## License

This configuration is provided under the same license as the OpenTelemetry Demo project.
