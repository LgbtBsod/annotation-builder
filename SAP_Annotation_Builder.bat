@echo off
chcp 65001 >nul 2>&1
title SAP Annotation Builder

:: Check PowerShell availability
where powershell >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: PowerShell not found.
    echo This app requires Windows 10/11 with PowerShell 5.1+
    pause
    exit /b 1
)

:: Run the PowerShell server
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0SAP_Annotation_Builder.ps1"

pause