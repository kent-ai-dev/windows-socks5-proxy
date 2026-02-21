# Windows SOCKS5 Proxy Server

A simple SOCKS5 proxy server for Windows. Run this on your UK VPS to bypass geo-restrictions.

## Quick Start

### Option 1: Python (Recommended)

1. Install Python 3.x from https://python.org if not already installed
2. Open PowerShell as Administrator
3. Run:
```powershell
cd C:\path\to\windows-socks5-proxy
pip install pysocks asyncio
python proxy_server.py
```

### Option 2: One-Click Batch File

1. Double-click `start_proxy.bat`
2. Copy the connection info displayed

## Output

When running, you'll see:
```
========================================
SOCKS5 PROXY SERVER RUNNING
========================================
External IP: 123.45.67.89
Port: 1080
Username: polymarket
Password: <random>

Connection String:
socks5://polymarket:<password>@123.45.67.89:1080
========================================
```

## Firewall

The script will attempt to open port 1080 in Windows Firewall. If it fails, manually run:
```powershell
netsh advfirewall firewall add rule name="SOCKS5 Proxy" dir=in action=allow protocol=TCP localport=1080
```

## Security

- Uses username/password authentication
- Generates random password on each start
- Only allows connections with valid credentials

## Configuration

Edit `config.txt` to change:
- Port (default: 1080)
- Username (default: polymarket)
- Password (leave empty for random)
