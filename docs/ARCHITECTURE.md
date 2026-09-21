# SAP Annotation Builder - Architecture Documentation

## Overview

SAP Annotation Builder is a PowerShell-based HTTP server module designed to serve web applications with advanced features like GZIP compression, ETag caching, CORS support, and modular architecture.

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    SAP Annotation Builder                     │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                  Main Script (PS1)                       │ │
│  │            Server initialization & lifecycle             │ │
│  └─────────────────────────────────────────────────────────┘ │
│                           │                                   │
│                           ▼                                   │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │               Core Module (PSM1)                         │ │
│  │                                                          │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │ │
│  │  │Configuration │  │   Logging    │  │   Security   │  │ │
│  │  │  Management  │  │   System     │  │   Features   │  │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  │ │
│  │                                                          │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │ │
│  │  │    HTTP      │  │   Request    │  │  Response    │  │ │
│  │  │   Server     │  │  Handlers    │  │  Handling    │  │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  │ │
│  │                                                          │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │ │
│  │  │    GZIP      │  │    ETag      │  │     MIME     │  │ │
│  │  │ Compression  │  │  Caching     │  │    Types     │  │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  │ │
│  └─────────────────────────────────────────────────────────┘ │
│                           │                                   │
│                           ▼                                   │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              HttpListener (.NET)                         │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
              ┌─────────────────────────┐
              │      Web Browser        │
              │   (Client Application)  │
              └─────────────────────────┘
```

## Component Diagram

### Module Structure

```
modules/
└── SAPAnnotationBuilder.psm1
    ├── Configuration Management
    │   ├── $Configuration (global hashtable)
    │   └── Initialize-Configuration()
    │
    ├── Logging System
    │   ├── Write-ServerLog()
    │   ├── Rotate-LogFile()
    │   └── Enter/Exit-CriticalSection()
    │
    ├── Compression
    │   └── Compress-Gzip()
    │
    ├── Caching
    │   ├── Get-ETag()
    │   └── Handle-ConditionalRequest()
    │
    ├── Security
    │   ├── Add-CorsHeaders()
    │   └── Resolve-SafeFilePath()
    │
    ├── MIME Types
    │   ├── Get-MimeType()
    │   └── IsCompressible()
    │
    ├── Helper Functions
    │   ├── Test-WebDirectory()
    │   └── Find-FreePort()
    │
    ├── Response Handling
    │   └── Send-Response()
    │
    ├── Request Handlers
    │   ├── Handle-Request()
    │   ├── Handle-FaviconRequest()
    │   ├── Handle-StaticFile()
    │   ├── Handle-SpaFallback()
    │   ├── Handle-OptionsRequest()
    │   └── Handle-HealthCheck()
    │
    ├── Server Lifecycle
    │   ├── Show-Banner()
    │   ├── Open-Browser()
    │   ├── Start-HttpServer()
    │   └── Stop-HttpServer()
    │
    └── Health Monitoring
        └── Get-HealthStatus()
```

## Data Flow

### Request Processing Flow

```
1. Client Request
         │
         ▼
2. HttpListener.GetContext()
         │
         ▼
3. Handle-Request()
         │
         ├─► OPTIONS? ──► Handle-OptionsRequest() ──► CORS headers
         │
         ├─► GET /health? ──► Handle-HealthCheck() ──► JSON response
         │
         ├─► GET /favicon.ico? ──► Handle-FaviconRequest()
         │
         └─► GET other?
                 │
                 ▼
         4. Resolve-SafeFilePath()
                 │
                 ├─► Invalid path? ──► 403 Forbidden
                 │
                 └─► Valid path?
                         │
                         ├─► File exists? ──► Handle-StaticFile()
                         │                        │
                         │                        ├─► Check ETag
                         │                        ├─► Apply GZIP
                         │                        └─► Send response
                         │
                         └─► File missing? ──► Handle-SpaFallback()
                                                  │
                                                  └─► Serve index.html
```

### Response Flow

```
Send-Response()
    │
    ├─► Add CORS headers (if enabled)
    │
    ├─► Check file size limit
    │   └─► Exceeded? ──► 413 Payload Too Large
    │
    ├─► Apply GZIP compression (if applicable)
    │   └─► Check content type
    │   └─► Check minimum size
    │   └─► Compress if beneficial
    │
    ├─► Set headers
    │   ├── Content-Type
    │   ├── Content-Encoding (gzip)
    │   ├── ETag
    │   └── Cache-Control
    │
    └─► Write to OutputStream
```

## Configuration System

### Configuration Hierarchy

```
1. Built-in Defaults (hardcoded in module)
         │
         │ (overridden by)
         ▼
2. Default Config File (settings.default.json)
         │
         │ (overridden by)
         ▼
3. User Config File (settings.json)
```

### Configuration Sections

```json
{
  "server": {
    "DefaultPort": 18765,
    "PortRange": 100,
    "PortRetryDelayMs": 50,
    "Host": "localhost"
  },
  "security": {
    "MaxFileSizeBytes": 52428800,
    "EnableCors": false,
    "AllowedOrigins": ["*"]
  },
  "performance": {
    "CacheMaxAgeSeconds": 31536000,
    "EnableGzip": true,
    "GzipMinSizeBytes": 1024,
    "RequestRetryDelayMs": 100
  },
  "logging": {
    "Level": "Info",
    "EnableFileLogging": false,
    "LogFilePath": "./logs/server.log",
    "MaxLogFileSizeBytes": 10485760,
    "MaxLogFiles": 5
  },
  "browser": {
    "AutoOpen": true,
    "OpenDelayMs": 1500
  },
  "paths": {
    "WebDirectory": "./web",
    "IndexFile": "index.html"
  }
}
```

## Security Features

### 1. Directory Traversal Prevention

```powershell
function Resolve-SafeFilePath {
    # Normalize path
    $filePath = [System.IO.Path]::GetFullPath(
        [System.IO.Path]::Combine($WebDirectory, $relativePath)
    )
    
    # Verify path is within web directory
    if (-not $filePath.StartsWith($webDirWithSeparator)) {
        return $null  # Block access
    }
    
    return $filePath
}
```

### 2. File Size Limits

```powershell
if ($Bytes.Length -gt $Configuration.Security.MaxFileSizeBytes) {
    # Return 413 Payload Too Large
    $response.StatusCode = 413
}
```

### 3. CORS Control

```powershell
function Add-CorsHeaders {
    if (-not $Configuration.Security.EnableCors) {
        return  # No CORS headers
    }
    
    # Add configured origins
    $Response.Headers.Add("Access-Control-Allow-Origin", $origin)
}
```

## Performance Optimizations

### 1. GZIP Compression

- **Threshold**: Only compress files > 1KB
- **Content Types**: text/html, text/css, application/javascript, application/json, etc.
- **Fallback**: Return original if compression doesn't reduce size

### 2. ETag Caching

```powershell
# Generate MD5 hash of file content
$eTag = "`"<hash>`""

# Check If-None-Match header
if ($ifNoneMatch -eq $eTag) {
    return 304 Not Modified  # No body sent
}
```

### 3. Cache-Control Headers

```powershell
# For static assets under /_next/
Cache-Control: public, max-age=31536000, immutable
```

### 4. Conditional Requests

- Reduces bandwidth for unchanged resources
- Uses HTTP 304 Not Modified response
- Based on ETag comparison

## Error Handling

### Exception Categories

1. **HttpListenerException**
   - Port binding failures
   - Network errors
   - Client disconnections

2. **IOException**
   - File read/write errors
   - Disk space issues

3. **ObjectDisposedException**
   - Already closed responses
   - Disposed streams

### Error Recovery

```powershell
try {
    # Operation
} catch [System.Net.HttpListenerException] {
    Write-ServerLog "Listener exception" -Level Debug
    # Graceful cleanup
} catch {
    Write-ServerLog "Unexpected error" -Level Warning
    # Abort response if needed
}
```

## Extension Points

### Adding New Handlers

```powershell
function Handle-CustomEndpoint {
    param([System.Net.HttpListenerContext]$Context)
    
    # Custom logic
    $data = @{ Message = "Hello" }
    $json = $data | ConvertTo-Json
    
    Send-Response -Context $Context -ContentType "application/json" ...
}

# Register in Handle-Request
if ($path -eq "/custom") {
    Handle-CustomEndpoint -Context $Context
    return
}
```

### Custom Middleware

```powershell
# Add logging middleware
function Invoke-RequestLogging {
    param($Context, $Next)
    
    $startTime = Get-Date
    & $Next  # Call next handler
    $duration = (Get-Date) - $startTime
    
    Write-Host "Request took $($duration.TotalMilliseconds)ms"
}
```

## Testing Architecture

### Test Layers

```
┌─────────────────────────────────────┐
│         Integration Tests           │  Full server lifecycle
├─────────────────────────────────────┤
│         Component Tests             │  Individual functions
├─────────────────────────────────────┤
│         Unit Tests                  │  Pure functions
└─────────────────────────────────────┘
```

### Mock Strategy

```powershell
# Mock external dependencies
Mock Test-Path { return $true }
Mock Get-Content { return "mocked content" }

# Test in isolation
It "Should handle missing file" {
    Mock Test-Path { return $false }
    $result = Test-WebDirectory -Path "/missing"
    $result | Should -BeFalse
}
```

## Deployment Considerations

### Prerequisites

- PowerShell 5.1+ or PowerShell 7+
- .NET Framework 4.5+ or .NET Core
- Administrative privileges (for port binding < 1024 on Linux)

### Port Selection

- Default: 18765
- Range: 100 ports (18765-18864)
- Automatic fallback if port in use

### File Structure

```
project/
├── modules/
│   └── SAPAnnotationBuilder.psm1
├── config/
│   ├── settings.default.json
│   └── settings.json
├── web/
│   ├── index.html
│   └── ... (static assets)
├── tests/
│   └── SAPAnnotationBuilder.Tests.ps1
├── docs/
│   └── *.md
└── SAP_Annotation_Builder.ps1
```

## Future Architecture Plans

See [ROADMAP.md](./ROADMAP.md) for detailed future plans including:

- Middleware pipeline architecture
- Dependency injection system
- Plugin system
- Cluster mode
- HTTP/2 and HTTP/3 support

## References

- [PowerShell Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/dev-cross-plat/)
- [Pester Testing Framework](https://pester.dev/)
- [.NET HttpListener](https://docs.microsoft.com/en-us/dotnet/api/system.net.httplistener)
