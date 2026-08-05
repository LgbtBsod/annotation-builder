<#
.SYNOPSIS
    SAP Annotation Builder — Modular HTTP Server Launcher
.DESCRIPTION
    Main entry point for SAP Annotation Builder.
    Uses modular architecture with JSON configuration support.
    Features: GZIP compression, ETag caching, CORS, file logging.
.NOTES
    Author: Chief Refactoring Engineer
    Version: 2.0.0
    Architecture: Modular with PSM1 module
#>

param(
    [int]$Port,
    [string]$ConfigPath = ""
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Import the core module
Import-Module (Join-Path $ScriptDir "modules\SAPAnnotationBuilder.psm1") -Force

# Initialize configuration from JSON
Initialize-Configuration -ConfigPath $ConfigPath

# Override port if specified via command line
if ($PSBoundParameters.ContainsKey('Port')) {
    $Configuration.Server.DefaultPort = $Port
}

# Resolve web directory path
$WebDir = Join-Path $ScriptDir $Configuration.Paths.WebDirectory
$Configuration.Paths.WebDirectory = $WebDir

#region Main Execution

# Validate web directory
if (-not (Test-WebDirectory -Path $WebDir)) {
    Read-Host "Press Enter to exit"
    exit 1
}

# Find available port
$portResult = Find-FreePort -StartPort $Configuration.Server.DefaultPort -Range $Configuration.Server.PortRange

if ($null -eq $portResult) {
    Write-ServerLog "Could not find a free port in range $($Configuration.Server.DefaultPort)..$($Configuration.Server.DefaultPort + $Configuration.Server.PortRange - 1)" -Level Error
    Read-Host "Press Enter to exit"
    exit 1
}

$http = $portResult.Listener
$ActualPort = $portResult.Port
$Url = "http://$($Configuration.Server.Host):$ActualPort"

# Display banner and open browser
Show-Banner -Url $Url
Open-Browser -Url $Url

# Start server loop
try {
    Start-HttpServer -Listener $http
} finally {
    Stop-HttpServer -Listener $http
}

#endregion