@echo off
call "%~dp0clean.bat"
if %errorlevel% neq 0 exit /b %errorlevel%
call "%~dp0build.bat"
if %errorlevel% neq 0 exit /b %errorlevel%
