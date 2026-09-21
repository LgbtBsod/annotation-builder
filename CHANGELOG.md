# Changelog - SAP Annotation Builder

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] - 2024-01-XX

### Changed
- **MAJOR**: Renamed all `Handle-*` functions to `Invoke-*` pattern for PowerShell standard compliance
  - `Handle-Request` → `Invoke-RequestHandler`
  - `Handle-FaviconRequest` → `Invoke-FaviconHandler`
  - `Handle-StaticFile` → `Invoke-StaticFileHandler`
  - `Handle-SpaFallback` → `Invoke-SpaFallbackHandler`
  - `Handle-OptionsRequest` → `Invoke-OptionsHandler`
  - `Handle-HealthCheck` → `Invoke-HealthCheckHandler`
  - `Handle-ConditionalRequest` → `Invoke-ConditionalRequestHandler`

### Added
- Enhanced comment-based help documentation for all handler functions
- Organized module exports by functional area with comments
- Improved function descriptions with detailed SYNOPSIS and DESCRIPTION sections
- Better inline code comments explaining security measures and caching logic

### Fixed
- Updated tests to use new `Invoke-*` function names
- All tests now pass (34 passed, 10 skipped for Linux compatibility)

### Technical Debt
- Resolved PowerShell unapproved verb warnings
- Improved code maintainability through consistent naming conventions

---

## [2.0.0] - Previous Release

### Added
- Health check endpoint (`/health`)
- GZIP compression support
- ETag-based conditional requests (304 Not Modified)
- CORS support with configurable origins
- File logging with rotation
- Modular architecture (PSM1)
- JSON configuration files
- Directory traversal protection
- SPA fallback for client-side routing

### Features
- Configurable port range with automatic discovery
- MIME type detection for common web assets
- Cache-Control headers for static assets
- Maximum file size enforcement
- Graceful server shutdown

---

## [1.0.0] - Initial Release

### Features
- Basic HTTP server functionality
- Static file serving
- Next.js application support
