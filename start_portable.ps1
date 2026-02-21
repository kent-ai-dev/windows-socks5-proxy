# Portable SOCKS5 Proxy - No Python Required
# Downloads and runs a portable proxy server

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Portable SOCKS5 Proxy Server" -ForegroundColor Cyan  
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[!] Please run as Administrator for firewall rules" -ForegroundColor Yellow
    Write-Host "    Right-click PowerShell -> Run as Administrator" -ForegroundColor Yellow
    Write-Host ""
}

# Configuration
$PORT = 1080
$USERNAME = "polymarket"
$PASSWORD = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 16 | % {[char]$_})

# Get external IP
Write-Host "[*] Getting external IP..." -ForegroundColor White
try {
    $EXTERNAL_IP = (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing -TimeoutSec 10).Content
    Write-Host "[+] External IP: $EXTERNAL_IP" -ForegroundColor Green
} catch {
    $EXTERNAL_IP = "YOUR_SERVER_IP"
    Write-Host "[!] Could not get external IP. Check manually." -ForegroundColor Yellow
}

# Download 3proxy if not exists
$proxyDir = "$PSScriptRoot\3proxy"
$proxyExe = "$proxyDir\3proxy.exe"

if (-not (Test-Path $proxyExe)) {
    Write-Host "[*] Downloading 3proxy portable..." -ForegroundColor White
    
    # Create directory
    New-Item -ItemType Directory -Force -Path $proxyDir | Out-Null
    
    # Download 3proxy (portable Windows build)
    $downloadUrl = "https://github.com/3proxy/3proxy/releases/download/0.9.4/3proxy-0.9.4.x64.zip"
    $zipPath = "$proxyDir\3proxy.zip"
    
    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing
        Write-Host "[+] Downloaded 3proxy" -ForegroundColor Green
        
        # Extract
        Expand-Archive -Path $zipPath -DestinationPath $proxyDir -Force
        
        # Find the exe (it's in a subdirectory)
        $exeFound = Get-ChildItem -Path $proxyDir -Recurse -Filter "3proxy.exe" | Select-Object -First 1
        if ($exeFound) {
            Copy-Item $exeFound.FullName $proxyExe -Force
            Write-Host "[+] Extracted 3proxy.exe" -ForegroundColor Green
        } else {
            throw "3proxy.exe not found in archive"
        }
        
        # Cleanup
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        
    } catch {
        Write-Host "[!] Download failed: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Manual download:" -ForegroundColor Yellow
        Write-Host "1. Go to: https://github.com/3proxy/3proxy/releases" -ForegroundColor White
        Write-Host "2. Download the Windows x64 zip" -ForegroundColor White
        Write-Host "3. Extract 3proxy.exe to: $proxyDir" -ForegroundColor White
        Read-Host "Press Enter after manual download"
    }
}

# Create config file
$configPath = "$proxyDir\3proxy.cfg"
$configContent = @"
# 3proxy SOCKS5 configuration
nscache 65536
timeouts 1 5 30 60 180 1800 15 60

# Authentication
users $USERNAME`:CL:$PASSWORD

# SOCKS5 proxy with auth on port $PORT
auth strong
socks -p$PORT
"@

$configContent | Out-File -FilePath $configPath -Encoding ASCII
Write-Host "[+] Config created" -ForegroundColor Green

# Add firewall rule
Write-Host "[*] Configuring firewall..." -ForegroundColor White
try {
    $existingRule = Get-NetFirewallRule -DisplayName "SOCKS5 Proxy 3proxy" -ErrorAction SilentlyContinue
    if (-not $existingRule) {
        New-NetFirewallRule -DisplayName "SOCKS5 Proxy 3proxy" -Direction Inbound -Protocol TCP -LocalPort $PORT -Action Allow | Out-Null
        Write-Host "[+] Firewall rule added for port $PORT" -ForegroundColor Green
    } else {
        Write-Host "[+] Firewall rule already exists" -ForegroundColor Green
    }
} catch {
    Write-Host "[!] Could not add firewall rule (run as Admin)" -ForegroundColor Yellow
    Write-Host "    Manual: netsh advfirewall firewall add rule name=`"SOCKS5`" dir=in action=allow protocol=TCP localport=$PORT" -ForegroundColor White
}

# Print connection info
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "SOCKS5 PROXY SERVER STARTING" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "External IP: $EXTERNAL_IP" -ForegroundColor White
Write-Host "Port: $PORT" -ForegroundColor White
Write-Host "Username: $USERNAME" -ForegroundColor White
Write-Host "Password: $PASSWORD" -ForegroundColor White
Write-Host ""
Write-Host "Connection String (COPY THIS):" -ForegroundColor Yellow
Write-Host "socks5://${USERNAME}:${PASSWORD}@${EXTERNAL_IP}:${PORT}" -ForegroundColor Cyan
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Keep this window open. Press Ctrl+C to stop." -ForegroundColor White
Write-Host ""

# Run the proxy
try {
    & $proxyExe $configPath
} catch {
    Write-Host "[!] Error running proxy: $_" -ForegroundColor Red
}

Read-Host "Press Enter to exit"
