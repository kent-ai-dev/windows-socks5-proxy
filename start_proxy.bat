@echo off
title SOCKS5 Proxy Server

echo Checking Python installation...
python --version >nul 2>&1
if errorlevel 1 (
    echo Python not found! Please install Python 3.x from https://python.org
    echo Make sure to check "Add Python to PATH" during installation.
    pause
    exit /b 1
)

echo Starting SOCKS5 Proxy Server...
echo.

python proxy_server.py

pause
