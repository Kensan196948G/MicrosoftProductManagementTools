@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo Microsoft 365 Management Tools
echo Starting PowerShell launcher...
if exist "Start-ManagementTools.ps1" (
    pwsh -ExecutionPolicy Bypass -File Start-ManagementTools.ps1
) else (
    echo ERROR: Start-ManagementTools.ps1 not found
    pause
)