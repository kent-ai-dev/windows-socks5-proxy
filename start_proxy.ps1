# SOCKS5 Proxy Server - PowerShell Launcher
# Run this as Administrator for automatic firewall configuration

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SOCKS5 Proxy Server Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[!] Not running as Administrator. Firewall rules may fail." -ForegroundColor Yellow
    Write-Host "    Right-click and 'Run as Administrator' for best results." -ForegroundColor Yellow
    Write-Host ""
}

# Check Python
Write-Host "[*] Checking Python installation..." -ForegroundColor White
try {
    $pythonVersion = python --version 2>&1
    Write-Host "[+] Found: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "[!] Python not found!" -ForegroundColor Red
    Write-Host "    Install from: https://python.org" -ForegroundColor Yellow
    Write-Host "    Make sure to check 'Add Python to PATH'" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Add firewall rule
Write-Host "[*] Configuring firewall..." -ForegroundColor White
try {
    $existingRule = Get-NetFirewallRule -DisplayName "SOCKS5 Proxy Server" -ErrorAction SilentlyContinue
    if ($existingRule) {
        Write-Host "[+] Firewall rule already exists" -ForegroundColor Green
    } else {
        New-NetFirewallRule -DisplayName "SOCKS5 Proxy Server" -Direction Inbound -Protocol TCP -LocalPort 1080 -Action Allow | Out-Null
        Write-Host "[+] Firewall rule added for port 1080" -ForegroundColor Green
    }
} catch {
    Write-Host "[!] Could not add firewall rule: $_" -ForegroundColor Yellow
    Write-Host "    You may need to add it manually." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "[*] Starting SOCKS5 Proxy Server..." -ForegroundColor White
Write-Host ""

# Run the Python server
python proxy_server.py

Read-Host "Press Enter to exit"
