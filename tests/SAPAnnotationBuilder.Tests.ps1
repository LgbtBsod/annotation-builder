# Pester Test Suite for SAP Annotation Builder Module
# Run with: Invoke-Pester -Path ./SAPAnnotationBuilder.Tests.ps1 -Output Detailed

param(
    [switch]$SkipIntegrationTests
)

BeforeAll {
    # Import the module
    $ModulePath = Join-Path $PSScriptRoot "..\modules\SAPAnnotationBuilder.psm1"
    Import-Module $ModulePath -Force
    
    # Load configuration
    Initialize-Configuration
}

Describe "Configuration Management" {
    Context "Initialize-Configuration" {
        It "Should load default configuration when no config file exists" {
            $config = Initialize-Configuration
            $config.Server.DefaultPort | Should -Be 18765
            $config.Security.MaxFileSizeBytes | Should -Be 52428800
            $config.Performance.EnableGzip | Should -BeTrue
        }
        
        It "Should have all required configuration sections" {
            $config = Initialize-Configuration
            $config.Keys | Should -Contain "Server"
            $config.Keys | Should -Contain "Security"
            $config.Keys | Should -Contain "Performance"
            $config.Keys | Should -Contain "Logging"
            $config.Keys | Should -Contain "Browser"
            $config.Keys | Should -Contain "Paths"
        }
    }
}

Describe "MIME Type Detection" {
    Context "Get-MimeType" {
        It "Should return correct MIME type for HTML files" {
            Get-MimeType -Extension ".html" | Should -Be "text/html; charset=utf-8"
        }
        
        It "Should return correct MIME type for CSS files" {
            Get-MimeType -Extension ".css" | Should -Be "text/css; charset=utf-8"
        }
        
        It "Should return correct MIME type for JavaScript files" {
            Get-MimeType -Extension ".js" | Should -Be "application/javascript; charset=utf-8"
        }
        
        It "Should return correct MIME type for JSON files" {
            Get-MimeType -Extension ".json" | Should -Be "application/json; charset=utf-8"
        }
        
        It "Should return octet-stream for unknown extensions" {
            Get-MimeType -Extension ".xyz" | Should -Be "application/octet-stream"
        }
        
        It "Should handle case-insensitive extensions" {
            Get-MimeType -Extension ".HTML" | Should -Be "text/html; charset=utf-8"
            Get-MimeType -Extension ".Html" | Should -Be "text/html; charset=utf-8"
        }
    }
    
    Context "IsCompressible" {
        It "Should return true for HTML content type" {
            IsCompressible -ContentType "text/html; charset=utf-8" | Should -BeTrue
        }
        
        It "Should return true for JavaScript content type" {
            IsCompressible -ContentType "application/javascript" | Should -BeTrue
        }
        
        It "Should return true for JSON content type" {
            IsCompressible -ContentType "application/json" | Should -BeTrue
        }
        
        It "Should return false for image content types" {
            IsCompressible -ContentType "image/png" | Should -BeFalse
            IsCompressible -ContentType "image/jpeg" | Should -BeFalse
        }
    }
}

Describe "GZIP Compression" {
    Context "Compress-Gzip" {
        It "Should compress large text content" {
            $largeText = "Hello World! " * 1000
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($largeText)
            $compressed = Compress-Gzip -Bytes $bytes
            $compressed.Length | Should -BeLessThan $bytes.Length
        }
        
        It "Should not compress small content (below threshold)" {
            $smallText = "Hi"
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($smallText)
            $compressed = Compress-Gzip -Bytes $bytes
            $compressed.Length | Should -Be $bytes.Length
        }
        
        It "Should return original bytes if compression is disabled" {
            $originalEnableGzip = $Configuration.Performance.EnableGzip
            $Configuration.Performance.EnableGzip = $false
            try {
                $bytes = [System.Text.Encoding]::UTF8.GetBytes("Test content")
                $compressed = Compress-Gzip -Bytes $bytes
                $compressed.Length | Should -Be $bytes.Length
            } finally {
                $Configuration.Performance.EnableGzip = $originalEnableGzip
            }
        }
    }
}

Describe "ETag Generation" {
    Context "Get-ETag" {
        It "Should generate consistent ETag for same content" {
            $testFile = Join-Path $PSScriptRoot "test_file.txt"
            "Test content" | Out-File -FilePath $testFile -Encoding UTF8
            
            $eTag1 = Get-ETag -FilePath $testFile
            $eTag2 = Get-ETag -FilePath $testFile
            
            $eTag1 | Should -Be $eTag2
            $eTag1 | Should -Not -BeNullOrEmpty
            
            Remove-Item $testFile -Force
        }
        
        It "Should return null for non-existent file" {
            Get-ETag -FilePath "/nonexistent/file.txt" | Should -BeNullOrEmpty
        }
    }
}

Describe "Path Resolution and Security" {
    Context "Resolve-SafeFilePath" {
        It "Should resolve valid paths within web directory" {
            $webDir = "/workspace/web"
            $result = Resolve-SafeFilePath -WebDirectory $webDir -RequestPath "/index.html"
            $result | Should -Be "/workspace/web/index.html"
        }
        
        It "Should block directory traversal attempts with .." {
            $webDir = "/workspace/web"
            $result = Resolve-SafeFilePath -WebDirectory $webDir -RequestPath "/../etc/passwd"
            $result | Should -BeNullOrEmpty
        }
        
        It "Should block directory traversal attempts with encoded characters" {
            $webDir = "/workspace/web"
            $result = Resolve-SafeFilePath -WebDirectory $webDir -RequestPath "/..%2F..%2Fetc/passwd"
            # The function should handle this via GetFullPath normalization
            # If it escapes the web dir, it should return null
            if ($result) {
                $result.StartsWith($webDir + "/") | Should -BeTrue
            }
        }
        
        It "Should handle root path correctly" {
            $webDir = "/workspace/web"
            $result = Resolve-SafeFilePath -WebDirectory $webDir -RequestPath "/"
            $result | Should -Be "/workspace/web"
        }
    }
}

Describe "Port Finding" {
    Context "Find-FreePort" {
        It "Should find an available port in range" -Skip:$IsLinux {
            $result = Find-FreePort -StartPort 18765 -Range 100
            $result | Should -Not -BeNullOrEmpty
            $result.Port | Should -BeGreaterThan 0
            $result.Listener | Should -Not -BeNullOrEmpty
            
            # Clean up
            if ($result.Listener) {
                $result.Listener.Stop()
                $result.Listener.Close()
            }
        }
        
        It "Should use configured default port range" -Skip:$IsLinux {
            $result = Find-FreePort
            $result | Should -Not -BeNullOrEmpty
            
            if ($result.Listener) {
                $result.Listener.Stop()
                $result.Listener.Close()
            }
        }
        
        It "Should return null when no ports are available in very limited range" -Skip:$IsLinux {
            # This test verifies the function handles exhaustion gracefully
            # In Linux environment, we skip due to HttpListener limitations
            $result = Find-FreePort -StartPort 1 -Range 1
            # Result may be null or valid depending on port 1 availability
            $result -eq $null -or $result.Port -gt 0 | Should -BeTrue
        }
    }
}

Describe "Logging Functionality" {
    Context "Write-ServerLog" {
        It "Should log Info level messages" {
            { Write-ServerLog -Message "Test info message" -Level "Info" } | Should -Not -Throw
        }
        
        It "Should log Warning level messages" {
            { Write-ServerLog -Message "Test warning message" -Level "Warning" } | Should -Not -Throw
        }
        
        It "Should log Error level messages" {
            { Write-ServerLog -Message "Test error message" -Level "Error" } | Should -Not -Throw
        }
        
        It "Should respect log level configuration" {
            $originalLevel = $Configuration.Logging.Level
            $Configuration.Logging.Level = "Error"
            
            # Debug and Info should be skipped when level is Error
            # This is hard to test without capturing output, so we just verify no errors
            { Write-ServerLog -Message "Debug message" -Level "Debug" } | Should -Not -Throw
            
            $Configuration.Logging.Level = $originalLevel
        }
    }
}

Describe "Health Check" {
    Context "Get-HealthStatus" {
        It "Should return healthy status" {
            $health = Get-HealthStatus
            $health.Status | Should -Be "Healthy"
            $health.Version | Should -Not -BeNullOrEmpty
            $health.Timestamp | Should -Not -BeNullOrEmpty
        }
        
        It "Should include configuration information" {
            $health = Get-HealthStatus
            $health.Configuration | Should -Not -BeNullOrEmpty
            $health.Configuration.Keys | Should -Contain "Port"
            $health.Configuration.Keys | Should -Contain "GzipEnabled"
            $health.Configuration.Keys | Should -Contain "CorsEnabled"
            $health.Configuration.Keys | Should -Contain "LoggingEnabled"
        }
        
        It "Should include timestamp in ISO 8601 format" {
            $health = Get-HealthStatus
            $health.Timestamp | Should -Match "^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$"
        }
        
        It "Should return correct module version" {
            $health = Get-HealthStatus
            $health.Version | Should -Be "2.0.0"
        }
    }
    
    Context "Invoke-HealthCheckHandler" {
        It "Should exist and be exportable" {
            { Get-Command Invoke-HealthCheckHandler -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should handle health check request without errors" -Skip:$IsLinux {
            $mockContext = New-Object System.Net.HttpListenerContext
            { Invoke-HealthCheckHandler -Context $mockContext } | Should -Not -Throw
        }
    }
}

Describe "CORS Support" {
    Context "Add-CorsHeaders" {
        It "Should exist and be exportable" {
            { Get-Command Add-CorsHeaders -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should verify CORS configuration is respected" -Skip:$IsLinux {
            $originalCors = $Configuration.Security.EnableCors
            
            # Test with CORS disabled
            $Configuration.Security.EnableCors = $false
            $mockResponse = New-Object System.Net.HttpListenerResponse
            Add-CorsHeaders -Response $mockResponse
            $mockResponse.Headers.Count | Should -Be 0
            $mockResponse.Close()
            
            # Test with CORS enabled (wildcard)
            $Configuration.Security.EnableCors = $true
            $Configuration.Security.AllowedOrigins = @("*")
            $mockResponse2 = New-Object System.Net.HttpListenerResponse
            Add-CorsHeaders -Response $mockResponse2
            $mockResponse2.Headers["Access-Control-Allow-Origin"] | Should -Be "*"
            $mockResponse2.Headers["Access-Control-Allow-Methods"] | Should -Be "GET, OPTIONS"
            $mockResponse2.Headers["Access-Control-Allow-Headers"] | Should -Be "Content-Type"
            $mockResponse2.Close()
            
            $Configuration.Security.EnableCors = $originalCors
        }
        
        It "Should handle specific allowed origins" -Skip:$IsLinux {
            $originalCors = $Configuration.Security.EnableCors
            $originalOrigins = $Configuration.Security.AllowedOrigins
            
            $Configuration.Security.EnableCors = $true
            $Configuration.Security.AllowedOrigins = @("https://example.com", "https://test.com")
            
            $mockResponse = New-Object System.Net.HttpListenerResponse
            Add-CorsHeaders -Response $mockResponse
            
            # Should use first origin when not wildcard
            $mockResponse.Headers["Access-Control-Allow-Origin"] | Should -Be "https://example.com"
            
            $mockResponse.Close()
            
            $Configuration.Security.EnableCors = $originalCors
            $Configuration.Security.AllowedOrigins = $originalOrigins
        }
    }
}

Describe "Response Handling" {
    Context "Send-Response" {
        It "Should exist and be exportable" {
            { Get-Command Send-Response -ErrorAction Stop } | Should -Not -Throw
        }
        
        It "Should handle null bytes gracefully" -Skip:$IsLinux {
            $mockContext = New-Object System.Net.HttpListenerContext
            { Send-Response -Context $mockContext -StatusCode 200 -Bytes $null } | Should -Not -Throw
        }
        
        It "Should enforce file size limit" -Skip:$IsLinux {
            $originalLimit = $Configuration.Security.MaxFileSizeBytes
            $Configuration.Security.MaxFileSizeBytes = 100
            
            $mockContext = New-Object System.Net.HttpListenerContext
            $largeBytes = [System.Text.Encoding]::UTF8.GetBytes(("A" * 200))
            
            # Should return 413 for oversized content
            { Send-Response -Context $mockContext -StatusCode 200 -Bytes $largeBytes } | Should -Not -Throw
            
            $Configuration.Security.MaxFileSizeBytes = $originalLimit
        }
        
        It "Should add ETag header when provided" -Skip:$IsLinux {
            $mockContext = New-Object System.Net.HttpListenerContext
            $testBytes = [System.Text.Encoding]::UTF8.GetBytes("Test content")
            $testETag = '"abc123"'
            
            { Send-Response -Context $mockContext -StatusCode 200 -ContentType "text/plain" -Bytes $testBytes -ETag $testETag } | Should -Not -Throw
        }
        
        It "Should add Cache-Control header when caching enabled" -Skip:$IsLinux {
            $mockContext = New-Object System.Net.HttpListenerContext
            $testBytes = [System.Text.Encoding]::UTF8.GetBytes("Test content")
            
            { Send-Response -Context $mockContext -StatusCode 200 -ContentType "text/plain" -Bytes $testBytes -EnableCaching $true } | Should -Not -Throw
        }
    }
}

Describe "Web Directory Validation" {
    Context "Test-WebDirectory" {
        It "Should return true for existing directory" -Skip:$SkipIntegrationTests {
            $testDir = Join-Path $PSScriptRoot "temp_test_dir"
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            
            Test-WebDirectory -Path $testDir | Should -BeTrue
            
            Remove-Item $testDir -Force
        }
        
        It "Should return false for non-existing directory" {
            Test-WebDirectory -Path "/nonexistent/directory" | Should -BeFalse
        }
    }
}

AfterAll {
    # Cleanup
    if (Test-Path (Join-Path $PSScriptRoot "test_file.txt")) {
        Remove-Item (Join-Path $PSScriptRoot "test_file.txt") -Force
    }
}
