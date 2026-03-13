@echo off
cd /d "%~dp0.."
zig build install
if %errorlevel% neq 0 (
    echo Build failed with exit code %errorlevel%.
    pause
    exit /b %errorlevel%
)
