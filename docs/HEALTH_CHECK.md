# Health Check Endpoint

## Overview

The SAP Annotation Builder now includes a `/health` endpoint for monitoring and diagnostics.

## Usage

### Endpoint Details

- **URL**: `http://localhost:18765/health`
- **Method**: GET
- **Content-Type**: `application/json; charset=utf-8`
- **Compression**: GZIP enabled

### Response Format

```json
{
  "Status": "Healthy",
  "Version": "2.0.0",
  "Timestamp": "2024-01-15T10:30:00Z",
  "Configuration": {
    "Port": 18765,
    "GzipEnabled": true,
    "CorsEnabled": false,
    "LoggingEnabled": false
  }
}
```

### Fields Description

| Field | Type | Description |
|-------|------|-------------|
| Status | string | Current health status ("Healthy") |
| Version | string | Module version number |
| Timestamp | string | ISO 8601 formatted timestamp |
| Configuration.Port | number | Configured server port |
| Configuration.GzipEnabled | boolean | Whether GZIP compression is enabled |
| Configuration.CorsEnabled | boolean | Whether CORS is enabled |
| Configuration.LoggingEnabled | boolean | Whether file logging is enabled |

## Use Cases

### 1. Service Monitoring

Use the health endpoint to monitor if the server is running:

```bash
curl -s http://localhost:18765/health | jq .Status
```

### 2. Load Balancer Health Checks

Configure your load balancer to check `/health` endpoint:

```
Health Check Path: /health
Expected Status: 200
Timeout: 5s
Interval: 30s
```

### 3. Application Diagnostics

Check server configuration without accessing logs:

```bash
curl -s http://localhost:18765/health | jq .Configuration
```

### 4. Container Orchestration

For Docker/Kubernetes deployments:

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:18765/health"]
  interval: 30s
  timeout: 5s
  retries: 3
```

## Implementation Notes

- The health endpoint bypasses caching (`Cache-Control` not set)
- Response is compressed with GZIP if enabled in configuration
- Returns 500 status code if health check fails internally
- Does not require authentication

## Related Functions

- `Get-HealthStatus` - Returns health data as hashtable
- `Handle-HealthCheck` - HTTP handler for /health endpoint

## Example PowerShell Usage

```powershell
Import-Module ./modules/SAPAnnotationBuilder.psm1

# Get health status programmatically
$health = Get-HealthStatus
Write-Host "Server version: $($health.Version)"
Write-Host "Status: $($health.Status)"
```
