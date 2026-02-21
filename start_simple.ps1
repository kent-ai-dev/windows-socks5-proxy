# Simple SOCKS5 Proxy - Uses microsocks (tiny ~20KB proxy)
# No dependencies required

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Simple SOCKS5 Proxy Server" -ForegroundColor Cyan  
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$PORT = 1080
$USERNAME = "poly"
$PASSWORD = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 12 | % {[char]$_})

# Get external IP
Write-Host "[*] Getting external IP..." -ForegroundColor White
try {
    $EXTERNAL_IP = (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing -TimeoutSec 10).Content.Trim()
    Write-Host "[+] External IP: $EXTERNAL_IP" -ForegroundColor Green
} catch {
    try {
        $EXTERNAL_IP = (Invoke-WebRequest -Uri "https://ifconfig.me/ip" -UseBasicParsing -TimeoutSec 10).Content.Trim()
        Write-Host "[+] External IP: $EXTERNAL_IP" -ForegroundColor Green
    } catch {
        $EXTERNAL_IP = "CHECK_YOUR_IP"
        Write-Host "[!] Could not get IP automatically" -ForegroundColor Yellow
    }
}

# Download gost (Go Simple Tunnel) - reliable SOCKS5 proxy
$proxyDir = "$PSScriptRoot\proxy"
$proxyExe = "$proxyDir\gost.exe"

if (-not (Test-Path $proxyExe)) {
    Write-Host "[*] Downloading proxy tool..." -ForegroundColor White
    
    New-Item -ItemType Directory -Force -Path $proxyDir | Out-Null
    
    # gost is a well-maintained Go proxy - single exe, no dependencies
    $downloadUrl = "https://github.com/ginuerzh/gost/releases/download/v2.11.5/gost-windows-amd64-2.11.5.zip"
    $zipPath = "$proxyDir\gost.zip"
    
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing
        Write-Host "[+] Downloaded proxy tool" -ForegroundColor Green
        
        Expand-Archive -Path $zipPath -DestinationPath $proxyDir -Force
        
        # Find gost.exe
        $exeFound = Get-ChildItem -Path $proxyDir -Recurse -Filter "gost*.exe" | Select-Object -First 1
        if ($exeFound) {
            Move-Item $exeFound.FullName $proxyExe -Force
            Write-Host "[+] Ready!" -ForegroundColor Green
        }
        
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
        
    } catch {
        Write-Host "[!] Download failed: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Manual fix:" -ForegroundColor Yellow
        Write-Host "1. Download from: https://github.com/ginuerzh/gost/releases" -ForegroundColor White
        Write-Host "2. Get: gost-windows-amd64-*.zip" -ForegroundColor White
        Write-Host "3. Extract gost.exe to: $proxyDir" -ForegroundColor White
        Read-Host "Press Enter after manual download"
    }
}

# Add firewall rule
Write-Host "[*] Configuring firewall..." -ForegroundColor White
try {
    netsh advfirewall firewall delete rule name="SOCKS5 Proxy" 2>$null
    netsh advfirewall firewall add rule name="SOCKS5 Proxy" dir=in action=allow protocol=TCP localport=$PORT | Out-Null
    Write-Host "[+] Firewall configured" -ForegroundColor Green
} catch {
    Write-Host "[!] Run as Administrator for firewall" -ForegroundColor Yellow
}

# Print connection info
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "PROXY READY - COPY THE LINE BELOW" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "socks5://${USERNAME}:${PASSWORD}@${EXTERNAL_IP}:${PORT}" -ForegroundColor Cyan
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Server Details:" -ForegroundColor White
Write-Host "  IP: $EXTERNAL_IP" -ForegroundColor Gray
Write-Host "  Port: $PORT" -ForegroundColor Gray
Write-Host "  User: $USERNAME" -ForegroundColor Gray
Write-Host "  Pass: $PASSWORD" -ForegroundColor Gray
Write-Host ""
Write-Host "Keep this window open! Ctrl+C to stop." -ForegroundColor Yellow
Write-Host ""

# Run the proxy with SOCKS5 and authentication
if (Test-Path $proxyExe) {
    & $proxyExe -L "socks5://${USERNAME}:${PASSWORD}@:${PORT}"
} else {
    Write-Host "[!] Proxy executable not found at: $proxyExe" -ForegroundColor Red
}

Read-Host "Press Enter to exit"
