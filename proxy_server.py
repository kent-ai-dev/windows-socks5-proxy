#!/usr/bin/env python3
"""
Simple SOCKS5 Proxy Server for Windows
Run this on your UK VPS to bypass Polymarket geo-restrictions.
"""

import asyncio
import socket
import struct
import secrets
import string
import subprocess
import sys
import os

# Configuration
PORT = 1080
USERNAME = "polymarket"
PASSWORD = None  # Will be generated if None

def get_external_ip():
    """Get the external IP address of this machine."""
    try:
        import urllib.request
        return urllib.request.urlopen('https://api.ipify.org', timeout=5).read().decode('utf-8')
    except:
        try:
            return urllib.request.urlopen('https://ifconfig.me/ip', timeout=5).read().decode('utf-8')
        except:
            return "UNKNOWN (check manually)"

def generate_password(length=16):
    """Generate a secure random password."""
    alphabet = string.ascii_letters + string.digits
    return ''.join(secrets.choice(alphabet) for _ in range(length))

def open_firewall_port(port):
    """Open the specified port in Windows Firewall."""
    try:
        subprocess.run([
            'netsh', 'advfirewall', 'firewall', 'add', 'rule',
            'name=SOCKS5 Proxy Server',
            'dir=in',
            'action=allow',
            'protocol=TCP',
            f'localport={port}'
        ], capture_output=True, check=True)
        print(f"[+] Firewall rule added for port {port}")
        return True
    except subprocess.CalledProcessError:
        print(f"[!] Could not add firewall rule. Run as Administrator or add manually.")
        return False
    except FileNotFoundError:
        print(f"[!] netsh not found (not Windows?). Add firewall rule manually.")
        return False

class SOCKS5Server:
    """Simple SOCKS5 proxy server with username/password authentication."""
    
    SOCKS_VERSION = 5
    
    def __init__(self, username: str, password: str):
        self.username = username.encode()
        self.password = password.encode()
    
    async def handle_client(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
        """Handle a single client connection."""
        addr = writer.get_extra_info('peername')
        
        try:
            # Step 1: Greeting - client sends supported auth methods
            header = await reader.readexactly(2)
            version, nmethods = struct.unpack("!BB", header)
            
            if version != self.SOCKS_VERSION:
                writer.close()
                return
            
            methods = await reader.readexactly(nmethods)
            
            # We require username/password auth (method 0x02)
            if 0x02 not in methods:
                writer.write(struct.pack("!BB", self.SOCKS_VERSION, 0xFF))  # No acceptable methods
                await writer.drain()
                writer.close()
                return
            
            # Accept username/password auth
            writer.write(struct.pack("!BB", self.SOCKS_VERSION, 0x02))
            await writer.drain()
            
            # Step 2: Username/Password authentication
            auth_version = await reader.readexactly(1)
            if auth_version != b'\x01':
                writer.close()
                return
            
            ulen = struct.unpack("!B", await reader.readexactly(1))[0]
            username = await reader.readexactly(ulen)
            
            plen = struct.unpack("!B", await reader.readexactly(1))[0]
            password = await reader.readexactly(plen)
            
            if username != self.username or password != self.password:
                writer.write(b'\x01\x01')  # Auth failed
                await writer.drain()
                writer.close()
                return
            
            writer.write(b'\x01\x00')  # Auth success
            await writer.drain()
            
            # Step 3: Connection request
            header = await reader.readexactly(4)
            version, cmd, _, atyp = struct.unpack("!BBBB", header)
            
            if version != self.SOCKS_VERSION or cmd != 0x01:  # Only CONNECT supported
                writer.write(struct.pack("!BBBBIH", self.SOCKS_VERSION, 0x07, 0, 1, 0, 0))
                await writer.drain()
                writer.close()
                return
            
            # Parse destination address
            if atyp == 0x01:  # IPv4
                dst_addr = socket.inet_ntoa(await reader.readexactly(4))
            elif atyp == 0x03:  # Domain name
                domain_len = struct.unpack("!B", await reader.readexactly(1))[0]
                dst_addr = (await reader.readexactly(domain_len)).decode()
            elif atyp == 0x04:  # IPv6
                dst_addr = socket.inet_ntop(socket.AF_INET6, await reader.readexactly(16))
            else:
                writer.close()
                return
            
            dst_port = struct.unpack("!H", await reader.readexactly(2))[0]
            
            # Step 4: Connect to destination
            try:
                remote_reader, remote_writer = await asyncio.wait_for(
                    asyncio.open_connection(dst_addr, dst_port),
                    timeout=10
                )
            except Exception as e:
                # Connection failed
                writer.write(struct.pack("!BBBBIH", self.SOCKS_VERSION, 0x05, 0, 1, 0, 0))
                await writer.drain()
                writer.close()
                return
            
            # Connection successful
            bind_addr = remote_writer.get_extra_info('sockname')
            bind_ip = socket.inet_aton(bind_addr[0]) if bind_addr else b'\x00\x00\x00\x00'
            bind_port = bind_addr[1] if bind_addr else 0
            
            writer.write(struct.pack("!BBBB", self.SOCKS_VERSION, 0x00, 0x00, 0x01) + bind_ip + struct.pack("!H", bind_port))
            await writer.drain()
            
            # Step 5: Relay data between client and destination
            await self.relay(reader, writer, remote_reader, remote_writer)
            
        except asyncio.IncompleteReadError:
            pass
        except Exception as e:
            pass
        finally:
            writer.close()
    
    async def relay(self, client_reader, client_writer, remote_reader, remote_writer):
        """Relay data between client and remote server."""
        async def forward(src, dst):
            try:
                while True:
                    data = await src.read(4096)
                    if not data:
                        break
                    dst.write(data)
                    await dst.drain()
            except:
                pass
            finally:
                dst.close()
        
        await asyncio.gather(
            forward(client_reader, remote_writer),
            forward(remote_reader, client_writer)
        )
    
    async def start(self, host='0.0.0.0', port=1080):
        """Start the SOCKS5 server."""
        server = await asyncio.start_server(self.handle_client, host, port)
        
        async with server:
            await server.serve_forever()


def main():
    global PASSWORD
    
    # Generate password if not set
    if PASSWORD is None:
        PASSWORD = generate_password()
    
    # Get external IP
    external_ip = get_external_ip()
    
    # Open firewall port
    open_firewall_port(PORT)
    
    # Print connection info
    print("\n" + "=" * 50)
    print("SOCKS5 PROXY SERVER RUNNING")
    print("=" * 50)
    print(f"External IP: {external_ip}")
    print(f"Port: {PORT}")
    print(f"Username: {USERNAME}")
    print(f"Password: {PASSWORD}")
    print()
    print("Connection String (copy this):")
    print(f"socks5://{USERNAME}:{PASSWORD}@{external_ip}:{PORT}")
    print("=" * 50)
    print("\nPress Ctrl+C to stop the server.\n")
    
    # Start server
    server = SOCKS5Server(USERNAME, PASSWORD)
    
    try:
        asyncio.run(server.start('0.0.0.0', PORT))
    except KeyboardInterrupt:
        print("\n[*] Server stopped.")


if __name__ == "__main__":
    main()
