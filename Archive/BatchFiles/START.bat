@echo off
REM ================================================================================
REM Microsoft 365 Management Tools - Windows Launcher
REM START.bat
REM ================================================================================

echo.
echo +======================================================================+
echo ^|                Microsoft 365 Management Tools                       ^|
echo ^|             ITSM/ISO27001/27002 Compliance System                   ^|
echo +======================================================================+
echo.

REM Set current directory
cd /d "%~dp0"

REM Check PowerShell availability
where pwsh >nul 2>&1
if %errorlevel% == 0 (
    echo Using PowerShell 7...
    pwsh -ExecutionPolicy Bypass -File Start-ManagementTools.ps1
    goto :end
)

where powershell >nul 2>&1
if %errorlevel% == 0 (
    echo Using Windows PowerShell...
    powershell -ExecutionPolicy Bypass -File Start-ManagementTools.ps1
    goto :end
)

echo ERROR: PowerShell not found
echo Please install PowerShell 7 or Windows PowerShell
pause
goto :end

:end
echo.
echo Press any key to continue...
pause >nul