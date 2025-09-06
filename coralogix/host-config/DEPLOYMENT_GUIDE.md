# OpenTelemetry Demo - Host Deployment Guide

## Overview

This guide provides a complete solution for deploying the OpenTelemetry demo directly on a host system with Coralogix agent and collector for observability. This setup is ideal for:

- Demonstrating OpenTelemetry capabilities on bare metal
- Creating guides for host monitoring
- Establishing correlation between logs, metrics, and traces
- Learning observability concepts without container orchestration complexity

## Solution Architecture

### Components

1. **Coralogix Agent** (systemd service)
   - Collects host system metrics and logs
   - Receives OpenTelemetry data from demo services
   - Applies sampling and transformations
   - Forwards data to Coralogix collector

2. **Coralogix Collector** (systemd service)
   - Aggregates data from multiple sources
   - Applies final processing and transformations
   - Exports to Coralogix platform

3. **OpenTelemetry Demo Services** (Docker containers)
   - E-commerce microservices demonstrating observability
   - Each service sends telemetry data to the collector
   - Includes frontend, backend services, and load generator

4. **Infrastructure Services** (Docker containers)
   - PostgreSQL, Redis, Kafka, Zookeeper
   - Required dependencies for the demo services

### Data Flow

```
Host System
├── System Logs & Metrics → Coralogix Agent
├── Demo Services (Docker) → Coralogix Agent
└── Coralogix Agent → Coralogix Collector → Coralogix Platform
```

## File Structure

```
coralogix/host-config/
├── agent.yaml                    # Coralogix agent configuration
├── collector.yaml                # Coralogix collector configuration
├── coralogix-agent.service       # systemd service for agent
├── coralogix-collector.service   # systemd service for collector
├── docker-compose-host.yml       # Demo services configuration
├── env.host                      # Environment variables template
├── install.sh                    # Coralogix installation script
├── setup-demo.sh                 # Demo services setup script
├── quick-start.sh                # Complete setup script
├── README.md                     # Detailed documentation
└── DEPLOYMENT_GUIDE.md          # This guide
```

## Quick Deployment

### Option 1: Automated Setup

```bash
# Clone the repository
git clone https://github.com/open-telemetry/opentelemetry-demo.git
cd opentelemetry-demo/coralogix/host-config

# Set your Coralogix private key
export CORALOGIX_PRIVATE_KEY="your_private_key_here"

# Run the complete setup
sudo ./quick-start.sh
```

### Option 2: Manual Setup

```bash
# 1. Install Coralogix services
sudo ./install.sh

# 2. Configure private key
sudo nano /etc/otelcol/coralogix.env
# Set: CORALOGIX_PRIVATE_KEY=your_private_key_here

# 3. Start Coralogix services
sudo systemctl start coralogix-agent coralogix-collector

# 4. Start demo services
cp env.host .env
# Edit .env with your private key
docker-compose -f docker-compose-host.yml up -d
```

## Configuration Details

### Coralogix Agent Configuration

The agent is configured to:

- **Collect Host Metrics**: CPU, memory, disk, network, processes
- **Collect System Logs**: /var/log/*.log, syslog, auth.log, kern.log
- **Receive OTLP Data**: gRPC (4317) and HTTP (4318) endpoints
- **Support Multiple Protocols**: Jaeger, Zipkin, StatsD, Prometheus
- **Apply Sampling**: 10% probabilistic sampling for traces
- **Transform Data**: Remove unnecessary attributes, add metadata
- **Export to Collector**: Forward processed data to Coralogix collector

### Coralogix Collector Configuration

The collector is configured to:

- **Receive from Agent**: OTLP gRPC and HTTP endpoints
- **Aggregate Data**: Combine data from multiple sources
- **Apply Final Processing**: Resource detection, transformations
- **Export to Coralogix**: Send logs, metrics, and traces to platform
- **Support Resource Catalog**: Send entity information for correlation

### Demo Services Configuration

Each demo service is configured with:

- **OTEL_EXPORTER_OTLP_ENDPOINT**: Points to Coralogix collector
- **OTEL_SERVICE_NAME**: Unique service identifier
- **OTEL_RESOURCE_ATTRIBUTES**: Service metadata and environment info
- **Service-specific Ports**: Each service runs on a different port

## Monitoring and Observability

### Metrics Collected

- **System Metrics**: CPU utilization, memory usage, disk I/O, network traffic
- **Application Metrics**: Request rates, response times, error rates
- **Business Metrics**: Order counts, revenue, user activity
- **Infrastructure Metrics**: Database connections, cache hit rates, queue depths

### Logs Collected

- **System Logs**: Kernel messages, authentication logs, system events
- **Application Logs**: Service-specific logs with structured data
- **Error Logs**: Exception traces, error messages, stack traces
- **Access Logs**: HTTP requests, API calls, user actions

### Traces Collected

- **Distributed Traces**: End-to-end request flows across services
- **Span Metrics**: Duration, status, error rates per operation
- **Database Traces**: Query execution times, connection pools
- **External Service Traces**: API calls, message queue operations

## Troubleshooting

### Common Issues

1. **Services Won't Start**
   ```bash
   # Check systemd services
   sudo systemctl status coralogix-agent coralogix-collector
   
   # Check Docker services
   docker-compose -f docker-compose-host.yml ps
   ```

2. **No Data in Coralogix**
   ```bash
   # Check agent logs
   sudo journalctl -u coralogix-agent -f
   
   # Check collector logs
   sudo journalctl -u coralogix-collector -f
   
   # Verify private key
   sudo cat /etc/otelcol/coralogix.env
   ```

3. **Port Conflicts**
   ```bash
   # Check port usage
   netstat -tlnp | grep -E ":(4317|4318|13133|3000|8080)"
   
   # Stop conflicting services
   sudo systemctl stop conflicting-service
   ```

### Health Checks

```bash
# Agent health
curl http://localhost:13133

# Collector health
curl http://localhost:13133

# Demo frontend
curl http://localhost:3000

# Load generator
curl http://localhost:8089
```

## Customization

### Adding Custom Metrics

Edit the agent configuration to add custom metrics:

```yaml
receivers:
  prometheus:
    config:
      scrape_configs:
      - job_name: custom-metrics
        static_configs:
        - targets: ['localhost:9090']
```

### Adding Custom Logs

Configure additional log sources:

```yaml
receivers:
  filelog:
    include:
    - /var/log/custom-app/*.log
    - /var/log/nginx/*.log
```

### Modifying Sampling

Adjust sampling rates:

```yaml
processors:
  probabilistic_sampler:
    sampling_percentage: 20  # 20% sampling
```

## Security Considerations

- **Service User**: Coralogix services run as `otelcol` user with minimal privileges
- **File Permissions**: Configuration files are read-only, private keys are restricted
- **Network Security**: Only necessary ports are exposed
- **Resource Limits**: Memory and CPU limits prevent resource exhaustion

## Performance Tuning

### Memory Optimization

```yaml
processors:
  memory_limiter:
    limit_percentage: 80
    spike_limit_percentage: 25
```

### Batch Processing

```yaml
processors:
  batch:
    send_batch_max_size: 4096
    timeout: 2s
```

### Sampling

```yaml
processors:
  probabilistic_sampler:
    sampling_percentage: 10
```

## Integration with Coralogix Platform

### Dashboards

Create custom dashboards using:
- System metrics for infrastructure monitoring
- Application metrics for service health
- Business metrics for user experience

### Alerts

Set up alerts for:
- High error rates
- Slow response times
- Resource utilization thresholds
- Service availability

### Log Analysis

Use Coralogix features:
- Log search and filtering
- Pattern recognition
- Anomaly detection
- Correlation with metrics and traces

## Best Practices

1. **Resource Monitoring**: Monitor system resources to prevent overload
2. **Log Rotation**: Implement log rotation to prevent disk space issues
3. **Backup Configuration**: Backup configuration files regularly
4. **Update Management**: Keep OpenTelemetry components updated
5. **Security Updates**: Apply security patches promptly

## Support and Maintenance

### Regular Maintenance

- Monitor service health and logs
- Update configurations as needed
- Apply security patches
- Clean up old log files

### Monitoring

- Set up alerts for service failures
- Monitor resource utilization
- Track data flow to Coralogix
- Verify data quality and completeness

## Conclusion

This host deployment provides a complete observability solution with:

- **Comprehensive Monitoring**: System, application, and business metrics
- **Centralized Logging**: Structured logs with correlation capabilities
- **Distributed Tracing**: End-to-end request tracking
- **Easy Setup**: Automated installation and configuration
- **Production Ready**: Security, performance, and reliability features

The solution is ideal for:
- Learning OpenTelemetry concepts
- Demonstrating observability capabilities
- Creating monitoring guides
- Establishing correlation between different telemetry types
- Building observability expertise

For additional support or questions, refer to the Coralogix documentation or contact support.
