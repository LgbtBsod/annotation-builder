<#
.SYNOPSIS
    SAP Annotation Builder — Portable HTTP Server
.DESCRIPTION
    Serves static web files and opens the browser.
    Works on any Windows PC without installing anything.
    PowerShell 5.1+ required (built into Windows 10/11).
#>

param(
    [int]$Port = 18765
)

$Title = "SAP Annotation Builder"

# Resolve directory where this script lives
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$WebDir = Join-Path $ScriptDir "web"

if (-not (Test-Path $WebDir)) {
    Write-Host "ERROR: Folder 'web' not found next to this script." -ForegroundColor Red
    Write-Host "Make sure the folder structure is preserved." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

# Find free port
$http = $null
for ($p = $Port; $p -lt $Port + 100; $p++) {
    try {
        $http = New-Object System.Net.HttpListener
        $http.Prefixes.Add("http://localhost:$p/")
        $http.Start()
        $Port = $p
        break
    } catch {
        if ($null -ne $http) { $http.Close(); $http = $null }
        Start-Sleep -Milliseconds 50
    }
}

if ($null -eq $http) {
    Write-Host "ERROR: Could not find a free port in range $Port..$($Port+99)" -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

$Url = "http://localhost:$Port"

# MIME types mapping
$MimeTypes = @{
    ".html" = "text/html; charset=utf-8"
    ".css"  = "text/css; charset=utf-8"
    ".js"   = "application/javascript; charset=utf-8"
    ".json" = "application/json; charset=utf-8"
    ".svg"  = "image/svg+xml"
    ".png"  = "image/png"
    ".jpg"  = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".gif"  = "image/gif"
    ".ico"  = "image/x-icon"
    ".woff" = "font/woff"
    ".woff2" = "font/woff2"
    ".txt"  = "text/plain; charset=utf-8"
    ".xml"  = "application/xml"
    ".map"  = "application/json"
}

# Print banner
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "       SAP Annotation Builder" -ForegroundColor White
Write-Host "       Portable Server" -ForegroundColor Gray
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Server: $Url" -ForegroundColor Green
Write-Host "  Press Ctrl+C to stop" -ForegroundColor DarkGray
Write-Host ""

# Open browser — wait 1.5s to ensure server is fully ready
Start-Sleep -Milliseconds 1500
try {
    Start-Process $Url
} catch {
    Write-Host "  WARNING: Could not open browser automatically." -ForegroundColor Yellow
    Write-Host "  Open manually: $Url" -ForegroundColor Yellow
}

# Handle requests — each request wrapped in try/catch
try {
    while ($http.IsListening) {
        # GetContext() blocks until a request arrives
        $context = $null
        try {
            $context = $http.GetContext()
        } catch [System.Net.HttpListenerException] {
            # Server stopped — exit cleanly
            break
        } catch {
            # Other errors on GetContext — wait and retry
            Start-Sleep -Milliseconds 100
            continue
        }

        # Handle this request in a try/catch so one bad request doesn't kill the server
        try {
            $request = $context.Request
            $response = $context.Response

            # Route
            $path = $request.Url.LocalPath
            if ($path -eq "/") { $path = "/index.html" }

            # Return empty 204 for favicon if not found (avoid SPA fallback for icons)
            if ($path -eq "/favicon.ico") {
                $faviconPath = Join-Path $WebDir "favicon.ico"
                if (Test-Path $faviconPath -PathType Leaf) {
                    $bytes = [System.IO.File]::ReadAllBytes($faviconPath)
                    $response.ContentType = "image/x-icon"
                    $response.ContentLength64 = $bytes.Length
                    $response.StatusCode = 200
                    $response.OutputStream.Write($bytes, 0, $bytes.Length)
                } else {
                    $response.StatusCode = 204
                    $response.ContentLength64 = 0
                }
                $response.Close()
                continue
            }

            # Security: prevent directory traversal
            $relativePath = $path.TrimStart("/")
            $filePath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($WebDir, $relativePath))

            # Ensure the resolved path is inside the web directory
            if (-not $filePath.StartsWith($WebDir + [System.IO.Path]::DirectorySeparatorChar) -and `
                -not $filePath.StartsWith($WebDir)) {
                $response.StatusCode = 403
                $response.StatusDescription = "Forbidden"
                $response.Close()
                continue
            }

            if (Test-Path $filePath -PathType Leaf) {
                # Serve the file
                $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
                $contentType = $MimeTypes[$ext]
                if (-not $contentType) { $contentType = "application/octet-stream" }

                $bytes = [System.IO.File]::ReadAllBytes($filePath)
                $response.ContentType = $contentType
                $response.ContentLength64 = $bytes.Length
                $response.StatusCode = 200

                # Cache static assets aggressively
                if ($path -match "^/_next/") {
                    try { $response.Headers.Add("Cache-Control", "public, max-age=31536000, immutable") } catch {}
                }

                $response.OutputStream.Write($bytes, 0, $bytes.Length)
            } else {
                # SPA fallback: serve index.html for all non-file paths
                $indexPath = Join-Path $WebDir "index.html"
                if (Test-Path $indexPath -PathType Leaf) {
                    $bytes = [System.IO.File]::ReadAllBytes($indexPath)
                    $response.ContentType = "text/html; charset=utf-8"
                    $response.ContentLength64 = $bytes.Length
                    $response.StatusCode = 200
                    $response.OutputStream.Write($bytes, 0, $bytes.Length)
                } else {
                    $response.StatusCode = 404
                    $response.StatusDescription = "Not Found"
                    $response.ContentLength64 = 0
                }
            }

            $response.Close()

        } catch [System.Net.HttpListenerException] {
            # Client disconnected — ignore and continue
            try { if ($context.Response) { $context.Response.Abort() } } catch {}
        } catch [System.IO.IOException] {
            # Connection was closed by client (browser cancelled request) — ignore
            try { if ($context.Response) { $context.Response.Abort() } } catch {}
        } catch [System.ObjectDisposedException] {
            # Response already disposed — ignore
        } catch {
            # Log unexpected errors but don't crash
            Write-Host "  [WARN] Request error: $($_.Exception.Message)" -ForegroundColor Yellow
            try { if ($context.Response) { $context.Response.Abort() } } catch {}
        }
    }
} catch [System.Net.HttpListenerException] {
    # Server stopped via Ctrl+C — expected
} finally {
    Write-Host ""
    Write-Host "  Server stopped." -ForegroundColor DarkGray
    try { if ($null -ne $http) { $http.Stop(); $http.Close() } } catch {}
}