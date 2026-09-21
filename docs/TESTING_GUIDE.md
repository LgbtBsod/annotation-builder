# SAP Annotation Builder - Testing Guide

## Overview

This guide provides comprehensive information about testing the SAP Annotation Builder PowerShell module.

## Test Framework

We use **Pester v5+** as our testing framework. Pester is the standard testing and mocking framework for PowerShell.

### Installation

```powershell
# Install Pester (if not already installed)
Install-Module -Name Pester -Force -SkipPublisherCheck -MinimumVersion 5.0.0

# Verify installation
Get-Module -Name Pester -ListAvailable
```

## Running Tests

### Basic Test Execution

```powershell
# Run all tests
Invoke-Pester -Path ./tests/SAPAnnotationBuilder.Tests.ps1

# Run with detailed output
Invoke-Pester -Path ./tests/SAPAnnotationBuilder.Tests.ps1 -Output Detailed

# Run with CI/CD friendly output
Invoke-Pester -Path ./tests/SAPAnnotationBuilder.Tests.ps1 -Output NUnitXml -CI

# Run specific test by tag
Invoke-Pester -Path ./tests/SAPAnnotationBuilder.Tests.ps1 -Tag "Security"
```

### Test Results

Example output:
```
Tests completed in 3.68s
Tests Passed: 34, Failed: 0, Skipped: 10, Inconclusive: 0, NotRun: 0
```

**Note**: Some tests are skipped on Linux due to `HttpListener` limitations. This is expected behavior.

## Test Structure

### Test File Organization

```
tests/
└── SAPAnnotationBuilder.Tests.ps1
```

### Test Sections

Our test suite covers the following areas:

1. **Configuration Management**
   - Default configuration loading
   - Configuration section validation

2. **MIME Type Detection**
   - Correct MIME types for various extensions
   - Case-insensitive handling
   - Compression eligibility

3. **GZIP Compression**
   - Large content compression
   - Small content bypass
   - Disabled compression handling

4. **ETag Generation**
   - Consistent ETag generation
   - Non-existent file handling

5. **Path Resolution and Security**
   - Valid path resolution
   - Directory traversal prevention
   - Path normalization

6. **Port Finding**
   - Available port detection
   - Port range configuration
   - Port exhaustion handling

7. **Logging Functionality**
   - Log level filtering
   - Message formatting
   - Error handling

8. **Health Check**
   - Status response format
   - Configuration information
   - Timestamp format validation

9. **CORS Support**
   - CORS header addition
   - Configuration respect
   - Origin handling

10. **Response Handling**
    - Null byte handling
    - File size limits
    - Header management

11. **Web Directory Validation**
    - Existing directory check
    - Missing directory handling

## Writing Tests

### Test Template

```powershell
Describe "Feature Name" {
    Context "Specific Context" {
        It "Should do something" {
            # Arrange
            $input = "test"
            
            # Act
            $result = Test-Function -Input $input
            
            # Assert
            $result | Should -Be "expected"
        }
        
        It "Should handle edge case" -Skip:$IsLinux {
            # Platform-specific test
        }
    }
}
```

### Best Practices

1. **Use BeforeAll/AfterAll**
   ```powershell
   BeforeAll {
       Import-Module ./modules/SAPAnnotationBuilder.psm1 -Force
   }
   
   AfterAll {
       # Cleanup
   }
   ```

2. **Test Isolation**
   - Each test should be independent
   - Clean up after tests
   - Use temporary files/directories

3. **Platform Compatibility**
   ```powershell
   # Skip tests that don't work on Linux
   It "Should work" -Skip:$IsLinux {
       # Windows-only test
   }
   ```

4. **Descriptive Test Names**
   - Use clear, descriptive names
   - Follow pattern: "Should [expected behavior]"

5. **Test Edge Cases**
   - Empty inputs
   - Null values
   - Boundary conditions
   - Error scenarios

## Mocking

### When to Mock

- External dependencies (file system, network)
- Slow operations
- Non-deterministic functions
- Functions with side effects

### Example

```powershell
It "Should handle file not found" {
    Mock Test-Path { return $false }
    
    $result = Test-WebDirectory -Path "/nonexistent"
    
    $result | Should -BeFalse
}
```

## Code Coverage

### Generate Coverage Report

```powershell
# Enable code coverage
$coverage = Invoke-Pester -Path ./tests -PassThru -CodeCoverage ./modules/*.psm1

# View coverage summary
$coverage.CodeCoverage.NumberOfCommandsExecuted
$coverage.CodeCoverage.TotalNumberOfCommands
```

### Coverage Goals

- **Current**: ~70%
- **Target v2.1**: 90%
- **Target v3.0**: 95%

## Continuous Integration

### GitHub Actions Example

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Run Pester Tests
        shell: pwsh
        run: |
          Install-Module -Name Pester -Force -SkipPublisherCheck
          Invoke-Pester -Path ./tests -Output JUnitXml -OutputFile test-results.xml
          
      - name: Publish Test Results
        uses: EnricoMi/publish-unit-test-result-action@v1
        if: always()
        with:
          files: test-results.xml
```

## Debugging Tests

### Run Single Test

```powershell
# Run specific test by name
Invoke-Pester -Path ./tests -FullNameFilter "*Should*health*"
```

### Verbose Output

```powershell
Invoke-Pester -Path ./tests -Output Detailed -Verbose
```

### Breakpoints

```powershell
It "Should debug this" {
    Set-PSBreakpoint -Line 100 -Script ./modules/SAPAnnotationBuilder.psm1
    $result = Test-Function
    $result | Should -Not -BeNullOrEmpty
}
```

## Performance Testing

### Benchmark Example

```powershell
Describe "Performance" {
    It "Should respond within 100ms" {
        $startTime = Get-Date
        $result = Invoke-WebRequest -Uri "http://localhost:18765/health"
        $duration = (Get-Date) - $startTime
        
        $duration.TotalMilliseconds | Should -BeLessThan 100
    }
}
```

## Common Issues

### Issue: Tests fail on Linux

**Solution**: Use `-Skip:$IsLinux` for platform-specific tests

```powershell
It "Should bind to port" -Skip:$IsLinux {
    # HttpListener test
}
```

### Issue: Module not found

**Solution**: Ensure correct path in BeforeAll

```powershell
BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot "..\modules\SAPAnnotationBuilder.psm1"
    Import-Module $ModulePath -Force
}
```

### Issue: Tests interfere with each other

**Solution**: Use proper cleanup in AfterEach/AfterAll

```powershell
AfterEach {
    # Reset configuration
    $Configuration.Security.EnableCors = $false
}
```

## Test Data

### Creating Test Files

```powershell
BeforeAll {
    $TestDir = Join-Path $PSScriptRoot "temp_test"
    New-Item -ItemType Directory -Path $TestDir -Force | Out-Null
}

AfterAll {
    Remove-Item $TestDir -Recurse -Force
}
```

### Test Constants

```powershell
$TestConstants = @{
    ValidPort = 18765
    InvalidPort = 0
    MaxFileSize = 52428800
    TestContent = "Hello World"
}
```

## Contributing Tests

### Pull Request Requirements

1. All new features must have tests
2. Bug fixes should include regression tests
3. Maintain or improve code coverage
4. Follow existing test patterns

### Test Review Checklist

- [ ] Tests are descriptive
- [ ] Tests are isolated
- [ ] Edge cases covered
- [ ] Platform compatibility considered
- [ ] Cleanup implemented
- [ ] No hardcoded paths
- [ ] Proper use of mocks

## Resources

- [Pester Documentation](https://pester.dev/docs/)
- [PowerShell Testing Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/testing/)
- [Effective PowerShell Testing](https://github.com/Pester/Pester/wiki)

## Support

For questions about testing:
- Check existing tests in `/tests`
- Review Pester documentation
- Open an issue on GitHub
