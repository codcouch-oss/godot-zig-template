@echo off
cd /d "%~dp0.."
zig build run -Dgodot="%godot%"
if %errorlevel% neq 0 (
    echo Run failed with exit code %errorlevel%.
    pause
    exit /b %errorlevel%
)
