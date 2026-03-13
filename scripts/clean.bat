@echo off
cd /d "%~dp0.."

echo The following will be deleted:
echo.
if exist .zig-cache echo   .zig-cache\
if exist zig-out echo   zig-out\
if exist binaries\zigtest.windows.x86_64.dll echo   binaries\zigtest.windows.x86_64.dll
echo.

set /p confirm=Proceed? (y/n):
if /i not "%confirm%"=="y" (
    echo Cancelled.
    exit /b 0
)

if exist .zig-cache rmdir /s /q .zig-cache
if %errorlevel% neq 0 (
    echo Clean failed with exit code %errorlevel%.
    pause
    exit /b %errorlevel%
)
if exist zig-out rmdir /s /q zig-out
if %errorlevel% neq 0 (
    echo Clean failed with exit code %errorlevel%.
    pause
    exit /b %errorlevel%
)
if exist binaries\zigtest.windows.x86_64.dll del /q binaries\zigtest.windows.x86_64.dll
if %errorlevel% neq 0 (
    echo Clean failed with exit code %errorlevel%.
    pause
    exit /b %errorlevel%
)
echo Clean complete.
