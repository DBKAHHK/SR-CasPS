# Firefly Go Proxy

A lightweight HTTP/HTTPS proxy server with domain redirection and request blocking capabilities. This tool is designed to help with local development and testing by intercepting and modifying HTTP/HTTPS traffic.

## Features

- HTTP/HTTPS proxy with MITM support
- Domain-based request redirection
- URL pattern blocking
- Automatic certificate management
- Cross-platform support (Windows, macOS, Linux)
- System proxy configuration

## Installation

### Prerequisites

- Go 1.22 or higher
- Git

### Building from source

```bash
cd firefly-go-proxy
go build
```

## Usage

### Basic usage

```bash
./firefly-proxy [flags] //linux|macos
./firefly-proxy.exe [flags] //windows
```

### Available Flags

- `-r`: Redirect target host (default: "127.0.0.1:21000")
- `-b`: Comma-separated list of blocked ports
- `-e`: Path to an executable to run with admin privileges

### Examples

1. Start proxy with default settings:
   ```bash
   ./firefly-proxy //linux|macos
   ./firefly-proxy.exe //windows
   ```

2. Redirect traffic to a different host:
   ```bash
   ./firefly-proxy -r 192.168.1.100:8080 //linux|macos
   ./firefly-proxy.exe -r 192.168.1.100:8080 //windows
   ```

3. Block specific ports:
   ```bash
   ./firefly-proxy -b "80,443,8080" //linux|macos
   ./firefly-proxy.exe -b "80,443,8080" //windows
   ```

4. Run an executable with admin privileges:
   ```bash
   ./firefly-proxy -e "/path/to/your/executable" //linux|macos
   ./firefly-proxy.exe -e "/path/to/your/executable" //windows
   ```

## How it works

The proxy intercepts HTTP/HTTPS traffic and can:
- Redirect requests based on domain names
- Block specific URLs or patterns
- Handle SSL/TLS connections with custom CA certificates
- Automatically configure system proxy settings

## License

MIT License


