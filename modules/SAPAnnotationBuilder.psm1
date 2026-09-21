<#
.SYNOPSIS
    SAP Annotation Builder - Core Server Module
.DESCRIPTION
    PowerShell module providing HTTP server functionality for SAP Annotation Builder.
    Implements modular architecture with configuration support, GZIP compression,
    ETag caching, CORS headers, and file logging.
.NOTES
    Author: Chief Refactoring Engineer
    Version: 2.0.0
    Architecture: Modular (PSM1)
#>

param(
    [string]$ConfigPath = ""
)

#region Module Constants
$MODULE_VERSION = "2.0.0"
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
#endregion

#region Configuration Management
$Configuration = @{
    Server = @{
        DefaultPort = 18765
        PortRange = 100
        PortRetryDelayMs = 50
        Host = "localhost"
    }
    Security = @{
        MaxFileSizeBytes = 52428800
        EnableCors = $false
        AllowedOrigins = @("*")
    }
    Performance = @{
        CacheMaxAgeSeconds = 31536000
        EnableGzip = $true
        GzipMinSizeBytes = 1024
        RequestRetryDelayMs = 100
    }
    Logging = @{
        Level = "Info"
        EnableFileLogging = $false
        LogFilePath = "./logs/server.log"
        MaxLogFileSizeBytes = 10485760
        MaxLogFiles = 5
    }
    Browser = @{
        AutoOpen = $true
        OpenDelayMs = 1500
    }
    Paths = @{
        WebDirectory = "./web"
        IndexFile = "index.html"
    }
}

function Initialize-Configuration {
    <#
    .SYNOPSIS
        Loads configuration from JSON file or uses defaults
    .PARAMETER ConfigPath
        Path to configuration JSON file
    .OUTPUTS
        Configuration hashtable
    #>
    param([string]$ConfigPath = "")
    
    $defaultConfigPath = Join-Path $SCRIPT_DIR "..\config\settings.default.json"
    $userConfigPath = if ($ConfigPath) { $ConfigPath } else { Join-Path $SCRIPT_DIR "..\config\settings.json" }
    
    $configToLoad = $defaultConfigPath
    
    if (Test-Path $userConfigPath) {
        $configToLoad = $userConfigPath
        Write-Verbose "Loading user configuration: $userConfigPath"
    } elseif (Test-Path $defaultConfigPath) {
        Write-Verbose "Loading default configuration: $defaultConfigPath"
    } else {
        Write-Verbose "Using built-in default configuration"
        return $Configuration
    }
    
    try {
        $jsonContent = Get-Content -Path $configToLoad -Raw -ErrorAction Stop
        $loadedConfig = $jsonContent | ConvertFrom-Json -ErrorAction Stop
        
        # Merge configuration recursively
        if ($loadedConfig.server) {
            foreach ($key in $loadedConfig.server.PSObject.Properties.Name) {
                $Configuration.Server[$key] = $loadedConfig.server.$key
            }
        }
        if ($loadedConfig.security) {
            foreach ($key in $loadedConfig.security.PSObject.Properties.Name) {
                $Configuration.Security[$key] = $loadedConfig.security.$key
            }
        }
        if ($loadedConfig.performance) {
            foreach ($key in $loadedConfig.performance.PSObject.Properties.Name) {
                $Configuration.Performance[$key] = $loadedConfig.performance.$key
            }
        }
        if ($loadedConfig.logging) {
            foreach ($key in $loadedConfig.logging.PSObject.Properties.Name) {
                $Configuration.Logging[$key] = $loadedConfig.logging.$key
            }
        }
        if ($loadedConfig.browser) {
            foreach ($key in $loadedConfig.browser.PSObject.Properties.Name) {
                $Configuration.Browser[$key] = $loadedConfig.browser.$key
            }
        }
        if ($loadedConfig.paths) {
            foreach ($key in $loadedConfig.paths.PSObject.Properties.Name) {
                $Configuration.Paths[$key] = $loadedConfig.paths.$key
            }
        }
        
        Write-Verbose "Configuration loaded successfully from: $configToLoad"
    } catch {
        Write-Warning "Failed to load configuration from $configToLoad : $($_.Exception.Message)"
        Write-Warning "Using built-in defaults"
    }
    
    return $Configuration
}
#endregion

#region Logging with File Support
$LogFileLock = New-Object System.Object

function Write-ServerLog {
    <#
    .SYNOPSIS
        Unified logging function with file support and rotation
    .PARAMETER Message
        Log message
    .PARAMETER Level
        Info, Warning, Error, Debug
    #>
    param(
        [string]$Message,
        [ValidateSet('Debug', 'Info', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    $logLevels = @('Debug', 'Info', 'Warning', 'Error')
    $currentLevelIndex = $logLevels.IndexOf($Configuration.Logging.Level)
    $messageLevelIndex = $logLevels.IndexOf($Level)
    
    # Skip if below configured log level
    if ($messageLevelIndex -lt $currentLevelIndex) {
        return
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Console output
    switch ($Level) {
        'Info'    { Write-Host $Message -ForegroundColor Green }
        'Warning' { Write-Host $Message -ForegroundColor Yellow }
        'Error'   { Write-Error $Message }
        'Debug'   { Write-Verbose $Message }
    }
    
    # File logging if enabled
    if ($Configuration.Logging.EnableFileLogging) {
        Enter-CriticalSection -Lock $LogFileLock
        try {
            $logDir = Split-Path -Parent $Configuration.Logging.LogFilePath
            if (-not (Test-Path $logDir)) {
                New-Item -ItemType Directory -Path $logDir -Force | Out-Null
            }
            
            # Check log file size for rotation
            if (Test-Path $Configuration.Logging.LogFilePath) {
                $fileSize = (Get-Item $Configuration.Logging.LogFilePath).Length
                if ($fileSize -ge $Configuration.Logging.MaxLogFileSizeBytes) {
                    Rotate-LogFile
                }
            }
            
            Add-Content -Path $Configuration.Logging.LogFilePath -Value $logEntry -Encoding UTF8
        } catch {
            Write-Verbose "Failed to write to log file: $($_.Exception.Message)"
        } finally {
            Exit-CriticalSection -Lock $LogFileLock
        }
    }
}

function Rotate-LogFile {
    <#
    .SYNOPSIS
        Rotates log file by renaming and removing old logs
    #>
    $logPath = $Configuration.Logging.LogFilePath
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($logPath)
    $extension = [System.IO.Path]::GetExtension($logPath)
    $logDir = Split-Path -Parent $logPath
    
    # Remove oldest log if at max
    $oldestLog = "$logDir\$baseName.$($Configuration.Logging.MaxLogFiles)$extension"
    if (Test-Path $oldestLog) {
        Remove-Item -Path $oldestLog -Force
    }
    
    # Shift existing rotated logs
    for ($i = ($Configuration.Logging.MaxLogFiles - 1); $i -ge 1; $i--) {
        $oldFile = "$logDir\$baseName.$i$extension"
        $newFile = "$logDir\$baseName.$($i + 1)$extension"
        if (Test-Path $oldFile) {
            Rename-Item -Path $oldFile -NewName $newFile -Force
        }
    }
    
    # Rotate current log
    if (Test-Path $logPath) {
        $newName = "$logDir\$baseName.1$extension"
        Rename-Item -Path $logPath -NewName $newName -Force
    }
}

function Enter-CriticalSection {
    param([System.Object]$Lock)
    [System.Threading.Monitor]::Enter($Lock)
}

function Exit-CriticalSection {
    param([System.Object]$Lock)
    [System.Threading.Monitor]::Exit($Lock)
}
#endregion

#region GZIP Compression
function Compress-Gzip {
    <#
    .SYNOPSIS
        Compresses byte array using GZIP
    .PARAMETER Bytes
        Raw bytes to compress
    .OUTPUTS
        GZIP compressed byte array
    #>
    param([byte[]]$Bytes)
    
    if (-not $Configuration.Performance.EnableGzip) {
        return $Bytes
    }
    
    if ($Bytes.Length -lt $Configuration.Performance.GzipMinSizeBytes) {
        return $Bytes
    }
    
    try {
        $memoryStream = New-Object System.IO.MemoryStream
        $gzipStream = New-Object System.IO.Compression.GZipStream($memoryStream, [System.IO.Compression.CompressionMode]::Compress)
        $gzipStream.Write($Bytes, 0, $Bytes.Length)
        $gzipStream.Close()
        $compressedBytes = $memoryStream.ToArray()
        $memoryStream.Close()
        
        # Only return compressed if smaller
        if ($compressedBytes.Length -lt $Bytes.Length) {
            return $compressedBytes
        }
        return $Bytes
    } catch {
        Write-ServerLog "  [DEBUG] GZIP compression failed: $($_.Exception.Message)" -Level Debug
        return $Bytes
    }
}
#endregion

#region ETag Generation
function Get-ETag {
    <#
    .SYNOPSIS
        Generates ETag header value from file content
    .PARAMETER FilePath
        Path to file
    .OUTPUTS
        ETag string (quoted MD5 hash)
    #>
    param([string]$FilePath)
    
    try {
        $bytes = [System.IO.File]::ReadAllBytes($FilePath)
        $md5 = [System.Security.Cryptography.MD5]::Create()
        $hash = $md5.ComputeHash($bytes)
        $hashString = [System.BitConverter]::ToString($hash) -replace '-', ''
        return "`"$hashString`""
    } catch {
        return $null
    }
}

function Invoke-ConditionalRequestHandler {
    <#
    .SYNOPSIS
        Checks If-None-Match header for 304 Not Modified response
    .DESCRIPTION
        Implements HTTP conditional request handling using ETag.
        If the client's If-None-Match header matches the current ETag,
        returns 304 Not Modified status without body.
    .PARAMETER Context
        HttpListenerContext
    .PARAMETER ETag
        Current ETag of the resource
    .OUTPUTS
        True if 304 was sent, False otherwise
    #>
    param(
        [System.Net.HttpListenerContext]$Context,
        [string]$ETag
    )
    
    $ifNoneMatch = $Context.Request.Headers["If-None-Match"]
    
    if ($ifNoneMatch -and ($ifNoneMatch -eq $ETag -or $ifNoneMatch -eq "*")) {
        $response = $Context.Response
        $response.StatusCode = 304
        $response.StatusDescription = "Not Modified"
        $response.ContentLength64 = 0
        $response.Close()
        return $true
    }
    
    return $false
}
#endregion

#region CORS Support
function Add-CorsHeaders {
    <#
    .SYNOPSIS
        Adds CORS headers to response if enabled
    .PARAMETER Response
        HttpListenerResponse object
    #>
    param([System.Net.HttpListenerResponse]$Response)
    
    if (-not $Configuration.Security.EnableCors) {
        return
    }
    
    try {
        $allowedOrigins = $Configuration.Security.AllowedOrigins
        if ($allowedOrigins -contains "*") {
            $Response.Headers.Add("Access-Control-Allow-Origin", "*")
        } else {
            # Could implement origin matching here
            $Response.Headers.Add("Access-Control-Allow-Origin", $allowedOrigins[0])
        }
        $Response.Headers.Add("Access-Control-Allow-Methods", "GET, OPTIONS")
        $Response.Headers.Add("Access-Control-Allow-Headers", "Content-Type")
        $Response.Headers.Add("Access-Control-Max-Age", "86400")
    } catch {
        Write-ServerLog "  [DEBUG] Failed to add CORS headers" -Level Debug
    }
}
#endregion

#region MIME Types
function Get-MimeType {
    <#
    .SYNOPSIS
        Returns MIME type for file extension
    .PARAMETER Extension
        File extension (e.g., '.html')
    .PARAMETER EnableGzip
        Whether to check if GZIP is applicable
    .OUTPUTS
        Content-Type header value
    #>
    param(
        [string]$Extension,
        [bool]$EnableGzip = $false
    )
    
    $MimeTypes = @{
        ".html"  = "text/html; charset=utf-8"
        ".css"   = "text/css; charset=utf-8"
        ".js"    = "application/javascript; charset=utf-8"
        ".json"  = "application/json; charset=utf-8"
        ".svg"   = "image/svg+xml"
        ".png"   = "image/png"
        ".jpg"   = "image/jpeg"
        ".jpeg"  = "image/jpeg"
        ".gif"   = "image/gif"
        ".ico"   = "image/x-icon"
        ".woff"  = "font/woff"
        ".woff2" = "font/woff2"
        ".txt"   = "text/plain; charset=utf-8"
        ".xml"   = "application/xml"
        ".map"   = "application/json"
    }
    
    $mimeType = $MimeTypes[$Extension] ?? "application/octet-stream"
    
    # Text-based types that can be GZIPped
    if ($EnableGzip -and $Configuration.Performance.EnableGzip) {
        $compressibleTypes = @("text/html", "text/css", "application/javascript", "application/json", "text/plain", "application/xml")
        foreach ($type in $compressibleTypes) {
            if ($mimeType.StartsWith($type)) {
                return $mimeType
            }
        }
    }
    
    return $mimeType
}

function IsCompressible {
    <#
    .SYNOPSIS
        Checks if content type supports GZIP compression
    .PARAMETER ContentType
        Content-Type header value
    .OUTPUTS
        True if compressible
    #>
    param([string]$ContentType)
    
    if (-not $Configuration.Performance.EnableGzip) {
        return $false
    }
    
    $compressibleTypes = @("text/html", "text/css", "application/javascript", "application/json", "text/plain", "application/xml", "image/svg+xml")
    
    foreach ($type in $compressibleTypes) {
        if ($ContentType.StartsWith($type)) {
            return $true
        }
    }
    
    return $false
}
#endregion

#region Helper Functions
function Test-WebDirectory {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        Write-ServerLog "Folder 'web' not found at: $Path" -Level Error
        Write-ServerLog "Make sure the folder structure is preserved." -Level Warning
        return $false
    }
    return $true
}

function Find-FreePort {
    <#
    .SYNOPSIS
        Finds an available port by attempting to bind HttpListener
    .PARAMETER StartPort
        Starting port number to check
    .PARAMETER Range
        Number of ports to try
    .OUTPUTS
        Hashtable with Listener and Port, or $null if no port found
    #>
    param(
        [int]$StartPort = $Configuration.Server.DefaultPort,
        [int]$Range = $Configuration.Server.PortRange
    )
    
    for ($p = $StartPort; $p -lt ($StartPort + $Range); $p++) {
        $httpListener = $null
        try {
            $httpListener = New-Object System.Net.HttpListener
            $host = $Configuration.Server.Host
            $httpListener.Prefixes.Add("http://$host`:$$p/")
            $httpListener.Start()
            
            # Successfully bound, return immediately
            return @{
                Listener = $httpListener
                Port = $p
            }
        } catch {
            # Clean up failed listener attempt
            if ($null -ne $httpListener) { 
                try { 
                    if ($httpListener.IsListening) {
                        $httpListener.Stop()
                    }
                    $httpListener.Close()
                    $httpListener.Dispose()
                } catch {
                    Write-ServerLog "  [DEBUG] Failed to cleanup listener on port $p" -Level Debug
                }
                $httpListener = $null 
            }
            Write-ServerLog "  [DEBUG] Port $p is unavailable, trying next..." -Level Debug
            Start-Sleep -Milliseconds $Configuration.Server.PortRetryDelayMs
        }
    }
    
    Write-ServerLog "  [ERROR] No available port found in range $StartPort-$($StartPort + $Range)" -Level Error
    return $null
}

function Resolve-SafeFilePath {
    param(
        [string]$WebDirectory,
        [string]$RequestPath
    )
    
    $relativePath = $RequestPath.TrimStart("/")
    $filePath = [System.IO.Path]::GetFullPath(
        [System.IO.Path]::Combine($WebDirectory, $relativePath)
    )
    
    $webDirWithSeparator = $WebDirectory + [System.IO.Path]::DirectorySeparatorChar
    
    if (-not $filePath.StartsWith($webDirWithSeparator, [System.StringComparison]::OrdinalIgnoreCase) -and 
        -not $filePath.Equals($WebDirectory, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $null
    }
    
    return $filePath
}
#endregion

#region Response Handling
function Send-Response {
    param(
        [System.Net.HttpListenerContext]$Context,
        [int]$StatusCode = 200,
        [string]$ContentType = "text/html; charset=utf-8",
        [byte[]]$Bytes = $null,
        [bool]$EnableCaching = $false,
        [string]$ETag = $null,
        [bool]$EnableCompression = $true
    )
    
    try {
        $response = $Context.Response
        
        # Add CORS headers
        Add-CorsHeaders -Response $response
        
        if ($null -eq $Bytes) {
            $response.StatusCode = $StatusCode
            $response.ContentLength64 = 0
            $response.Close()
            return
        }
        
        # Enforce file size limit
        if ($Bytes.Length -gt $Configuration.Security.MaxFileSizeBytes) {
            Write-ServerLog "  [WARN] File exceeds size limit: $($Bytes.Length) bytes" -Level Warning
            $response.StatusCode = 413
            $response.StatusDescription = "Payload Too Large"
            $response.ContentLength64 = 0
            $response.Close()
            return
        }
        
        # Apply GZIP compression if applicable
        $finalBytes = $Bytes
        $contentEncoding = $null
        
        if ($EnableCompression -and (IsCompressible -ContentType $ContentType)) {
            $compressedBytes = Compress-Gzip -Bytes $Bytes
            if ($compressedBytes.Length -lt $Bytes.Length) {
                $finalBytes = $compressedBytes
                $contentEncoding = "gzip"
            }
        }
        
        $response.ContentType = $ContentType
        $response.ContentLength64 = $finalBytes.Length
        $response.StatusCode = $StatusCode
        
        if ($contentEncoding) {
            $response.Headers.Add("Content-Encoding", $contentEncoding)
        }
        
        if ($ETag) {
            $response.Headers.Add("ETag", $ETag)
        }
        
        if ($EnableCaching) {
            try { 
                $response.Headers.Add("Cache-Control", "public, max-age=$($Configuration.Performance.CacheMaxAgeSeconds), immutable") 
            } catch {
                Write-ServerLog "  [DEBUG] Could not set Cache-Control header" -Level Debug
            }
        }
        
        $response.OutputStream.Write($finalBytes, 0, $finalBytes.Length)
        $response.Close()
        
    } catch [System.Net.HttpListenerException] {
        Write-ServerLog "  [DEBUG] Client disconnected during response" -Level Debug
        try { if ($Context.Response) { $Context.Response.Abort() } } catch {}
    } catch [System.IO.IOException] {
        Write-ServerLog "  [DEBUG] Connection closed by client" -Level Debug
        try { if ($Context.Response) { $Context.Response.Abort() } } catch {}
    } catch [System.ObjectDisposedException] {
        Write-ServerLog "  [DEBUG] Response already disposed" -Level Debug
    } catch {
        Write-ServerLog "  [WARN] Response error: $($_.Exception.Message)" -Level Warning
        try { if ($Context.Response) { $Context.Response.Abort() } } catch {}
    }
}
#endregion

#region Request Handlers
function Invoke-FaviconHandler {
    <#
    .SYNOPSIS
        Handles favicon.ico requests with caching support
    .PARAMETER Context
        HttpListenerContext
    .PARAMETER WebDirectory
        Path to web directory
    #>
    param(
        [System.Net.HttpListenerContext]$Context,
        [string]$WebDirectory
    )
    
    $faviconPath = Join-Path $WebDirectory "favicon.ico"
    
    if (Test-Path $faviconPath -PathType Leaf) {
        try {
            $bytes = [System.IO.File]::ReadAllBytes($faviconPath)
            $eTag = Get-ETag -FilePath $faviconPath
            
            if (Invoke-ConditionalRequestHandler -Context $Context -ETag $eTag) {
                return
            }
            
            Send-Response -Context $Context -StatusCode 200 -ContentType "image/x-icon" -Bytes $bytes -ETag $eTag -EnableCaching $true
        } catch {
            Send-Response -Context $Context -StatusCode 204
        }
    } else {
        Send-Response -Context $Context -StatusCode 204
    }
}

function Invoke-StaticFileHandler {
    <#
    .SYNOPSIS
        Serves static files with ETag caching and GZIP compression
    .PARAMETER Context
        HttpListenerContext
    .PARAMETER FilePath
        Full path to the file
    .PARAMETER RequestPath
        Original request path for caching logic
    #>
    param(
        [System.Net.HttpListenerContext]$Context,
        [string]$FilePath,
        [string]$RequestPath
    )
    
    try {
        $ext = [System.IO.Path]::GetExtension($FilePath).ToLower()
        $contentType = Get-MimeType -Extension $ext -EnableGzip $true
        $bytes = [System.IO.File]::ReadAllBytes($FilePath)
        $eTag = Get-ETag -FilePath $FilePath
        
        # Check conditional request (If-None-Match)
        if ($eTag -and (Invoke-ConditionalRequestHandler -Context $Context -ETag $eTag)) {
            return
        }
        
        # Enable aggressive caching for Next.js assets
        $enableCaching = ($RequestPath -match "^/_next/")
        
        Send-Response -Context $Context -StatusCode 200 -ContentType $contentType -Bytes $bytes -ETag $eTag -EnableCaching $enableCaching
    } catch [System.IO.IOException] {
        Write-ServerLog "  [WARN] Could not read file: $FilePath" -Level Warning
        Send-Response -Context $Context -StatusCode 500
    } catch {
        Write-ServerLog "  [WARN] Error serving file: $($_.Exception.Message)" -Level Warning
        Send-Response -Context $Context -StatusCode 500
    }
}

function Invoke-SpaFallbackHandler {
    <#
    .SYNOPSIS
        Handles SPA fallback by serving index.html for client-side routing
    .PARAMETER Context
        HttpListenerContext
    .PARAMETER WebDirectory
        Path to web directory
    #>
    param(
        [System.Net.HttpListenerContext]$Context,
        [string]$WebDirectory
    )
    
    $indexPath = Join-Path $WebDirectory $Configuration.Paths.IndexFile
    
    if (Test-Path $indexPath -PathType Leaf) {
        try {
            $bytes = [System.IO.File]::ReadAllBytes($indexPath)
            $eTag = Get-ETag -FilePath $indexPath
            
            if (Invoke-ConditionalRequestHandler -Context $Context -ETag $eTag) {
                return
            }
            
            Send-Response -Context $Context -StatusCode 200 -ContentType "text/html; charset=utf-8" -Bytes $bytes -ETag $eTag
        } catch {
            Send-Response -Context $Context -StatusCode 500
        }
    } else {
        Send-Response -Context $Context -StatusCode 404
    }
}

function Invoke-OptionsHandler {
    <#
    .SYNOPSIS
        Handles OPTIONS preflight requests for CORS
    .DESCRIPTION
        Returns 204 No Content with appropriate CORS headers if CORS is enabled.
        Returns 405 Method Not Allowed if CORS is disabled.
    .PARAMETER Context
        HttpListenerContext
    #>
    param([System.Net.HttpListenerContext]$Context)
    
    if ($Configuration.Security.EnableCors) {
        $response = $Context.Response
        $response.StatusCode = 204
        Add-CorsHeaders -Response $response
        $response.Close()
    } else {
        Send-Response -Context $Context -StatusCode 405
    }
}

function Invoke-HealthCheckHandler {
    <#
    .SYNOPSIS
        Handles /health endpoint for monitoring and diagnostics
    .DESCRIPTION
        Returns JSON response with server health status, version, timestamp,
        and configuration information. Supports GZIP compression.
    .PARAMETER Context
        HttpListenerContext
    #>
    param([System.Net.HttpListenerContext]$Context)
    
    try {
        $healthData = Get-HealthStatus
        $jsonContent = $healthData | ConvertTo-Json -Depth 3 -Compress:$false
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($jsonContent)
        
        Send-Response -Context $Context -StatusCode 200 -ContentType "application/json; charset=utf-8" -Bytes $bytes -EnableCaching $false -EnableCompression $true
    } catch {
        Write-ServerLog "  [ERROR] Health check failed: $($_.Exception.Message)" -Level Error
        Send-Response -Context $Context -StatusCode 500
    }
}

function Invoke-RequestHandler {
    <#
    .SYNOPSIS
        Main request router for HTTP server
    .DESCRIPTION
        Routes incoming HTTP requests to appropriate handlers based on method and path.
        Supports GET and OPTIONS methods only. Implements security checks and SPA fallback.
    .PARAMETER Context
        HttpListenerContext
    #>
    param([System.Net.HttpListenerContext]$Context)
    
    try {
        $request = $Context.Request
        $path = $request.Url.LocalPath
        $method = $request.HttpMethod
        
        # Handle OPTIONS for CORS preflight
        if ($method -eq "OPTIONS") {
            Invoke-OptionsHandler -Context $Context
            return
        }
        
        # Only allow GET method
        if ($method -ne "GET") {
            Send-Response -Context $Context -StatusCode 405
            return
        }
        
        # Default route - serve index.html
        if ($path -eq "/") { 
            $path = "/" + $Configuration.Paths.IndexFile
        }
        
        # Health check endpoint
        if ($path -eq "/health") {
            Invoke-HealthCheckHandler -Context $Context
            return
        }
        
        # Favicon handling
        if ($path -eq "/favicon.ico") {
            Invoke-FaviconHandler -Context $Context -WebDirectory $Configuration.Paths.WebDirectory
            return
        }
        
        # Security: resolve and validate path (prevent directory traversal)
        $filePath = Resolve-SafeFilePath -WebDirectory $Configuration.Paths.WebDirectory -RequestPath $path
        
        if ($null -eq $filePath) {
            Write-ServerLog "  [WARN] Directory traversal attempt blocked: $path" -Level Warning
            Send-Response -Context $Context -StatusCode 403
            return
        }
        
        # Serve static file or fallback to index.html for SPA routing
        if (Test-Path $filePath -PathType Leaf) {
            Invoke-StaticFileHandler -Context $Context -FilePath $filePath -RequestPath $path
        } else {
            Invoke-SpaFallbackHandler -Context $Context -WebDirectory $Configuration.Paths.WebDirectory
        }
        
    } catch [System.Net.HttpListenerException] {
        Write-ServerLog "  [DEBUG] Listener exception during request" -Level Debug
        try { if ($Context.Response) { $Context.Response.Abort() } } catch {}
    } catch {
        Write-ServerLog "  [WARN] Unexpected request error: $($_.Exception.Message)" -Level Warning
        try { if ($Context.Response) { $Context.Response.Abort() } } catch {}
    }
}
#endregion

#region Server Lifecycle
function Show-Banner {
    param([string]$Url)
    
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host "       SAP Annotation Builder v$MODULE_VERSION" -ForegroundColor White
    Write-Host "       Modular HTTP Server" -ForegroundColor Gray
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Server: $Url" -ForegroundColor Green
    Write-Host "  Max file size: $($Configuration.Security.MaxFileSizeBytes / 1MB) MB" -ForegroundColor DarkGray
    Write-Host "  GZIP: $(if ($Configuration.Performance.EnableGzip) { 'Enabled' } else { 'Disabled' })" -ForegroundColor DarkGray
    Write-Host "  ETag Caching: Enabled" -ForegroundColor DarkGray
    Write-Host "  CORS: $(if ($Configuration.Security.EnableCors) { 'Enabled' } else { 'Disabled' })" -ForegroundColor DarkGray
    Write-Host "  File Logging: $(if ($Configuration.Logging.EnableFileLogging) { 'Enabled' } else { 'Disabled' })" -ForegroundColor DarkGray
    Write-Host "  Press Ctrl+C to stop" -ForegroundColor DarkGray
    Write-Host ""
}

function Open-Browser {
    param([string]$Url)
    
    if (-not $Configuration.Browser.AutoOpen) {
        Write-ServerLog "  Auto-open browser disabled" -Level Debug
        return
    }
    
    Start-Sleep -Milliseconds $Configuration.Browser.OpenDelayMs
    
    try {
        Start-Process $Url
    } catch {
        Write-ServerLog "  WARNING: Could not open browser automatically." -Level Warning
        Write-ServerLog "  Open manually: $Url" -Level Warning
    }
}

function Start-HttpServer {
    param([System.Net.HttpListener]$Listener)
    
    try {
        while ($Listener.IsListening) {
            $context = $null
            
            try {
                $context = $Listener.GetContext()
            } catch [System.Net.HttpListenerException] {
                break
            } catch {
                Start-Sleep -Milliseconds $Configuration.Performance.RequestRetryDelayMs
                continue
            }
            
            if ($null -ne $context) {
                Handle-Request -Context $context
            }
        }
    } catch [System.Net.HttpListenerException] {
        # Expected on Ctrl+C
    } catch {
        Write-ServerLog "  [ERROR] Server error: $($_.Exception.Message)" -Level Error
    }
}

function Stop-HttpServer {
    param([System.Net.HttpListener]$Listener)
    
    Write-Host ""
    Write-Host "  Server stopped." -ForegroundColor DarkGray
    
    if ($null -ne $Listener) {
        try { 
            $Listener.Stop()
            $Listener.Close()
        } catch {
            Write-ServerLog "  [WARN] Error during shutdown: $($_.Exception.Message)" -Level Warning
        }
    }
}
#endregion

#region Health Check Endpoint
function Get-HealthStatus {
    <#
    .SYNOPSIS
        Returns server health status as hashtable
    .OUTPUTS
        Hashtable with health information
    #>
    return @{
        Status = "Healthy"
        Version = $MODULE_VERSION
        Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        Configuration = @{
            Port = $Configuration.Server.DefaultPort
            GzipEnabled = $Configuration.Performance.EnableGzip
            CorsEnabled = $Configuration.Security.EnableCors
            LoggingEnabled = $Configuration.Logging.EnableFileLogging
        }
    }
}
#endregion

#region Module Exports
# Core functions
Export-ModuleMember -Function Initialize-Configuration
Export-ModuleMember -Function Write-ServerLog

# MIME and compression
Export-ModuleMember -Function Get-MimeType
Export-ModuleMember -Function IsCompressible
Export-ModuleMember -Function Compress-Gzip

# Caching
Export-ModuleMember -Function Get-ETag
Export-ModuleMember -Function Invoke-ConditionalRequestHandler

# Security
Export-ModuleMember -Function Resolve-SafeFilePath
Export-ModuleMember -Function Add-CorsHeaders

# Port management
Export-ModuleMember -Function Find-FreePort

# Request handlers (Invoke-* pattern for PowerShell standard compliance)
Export-ModuleMember -Function Invoke-RequestHandler
Export-ModuleMember -Function Invoke-FaviconHandler
Export-ModuleMember -Function Invoke-StaticFileHandler
Export-ModuleMember -Function Invoke-SpaFallbackHandler
Export-ModuleMember -Function Invoke-OptionsHandler
Export-ModuleMember -Function Invoke-HealthCheckHandler

# Response handling
Export-ModuleMember -Function Send-Response

# Server lifecycle
Export-ModuleMember -Function Start-HttpServer
Export-ModuleMember -Function Stop-HttpServer
Export-ModuleMember -Function Show-Banner
Export-ModuleMember -Function Open-Browser

# Health monitoring
Export-ModuleMember -Function Get-HealthStatus

# Web directory validation
Export-ModuleMember -Function Test-WebDirectory

# Variables
Export-ModuleMember -Variable Configuration
Export-ModuleMember -Variable MODULE_VERSION
#endregion
