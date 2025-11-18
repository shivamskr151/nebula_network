# Nebula VPN Network - Cross-Network Camera Streaming

A secure, containerized solution for streaming camera feeds across networks using [Nebula VPN](https://github.com/slackhq/nebula). This project enables remote access to camera streams (webcam/IP camera) from anywhere on the internet through an encrypted Nebula mesh network.

## 🎯 Features

- **Secure VPN Connection**: End-to-end encrypted communication using Nebula VPN
- **RTSP Streaming**: Real-time camera streaming using MediaMTX RTSP server
- **Docker-Based**: Fully containerized setup for easy deployment
- **Cross-Platform**: Works on macOS, Linux, and Windows
- **Automated Setup**: Scripts for certificate generation and testing
- **Webcam Support**: Native macOS webcam streaming support
- **Remote Recording**: Automatic stream recording on the client side

## 📋 Prerequisites

- **Docker** and **Docker Compose** installed and running
- **Nebula Cert Tool** (`nebula-cert`) for generating certificates
  - Download from [Nebula Releases](https://github.com/slackhq/nebula/releases)
  - Or install via Homebrew: `brew install nebula`
- **ffmpeg** (for webcam streaming on macOS)
- **Network Access**: Lighthouse needs UDP port 4242 accessible from the internet

## 🏗️ Architecture

```
┌─────────────────────────────────────────┐
│  Lighthouse Network (Camera Location)   │
│                                         │
│  ┌──────────────┐                      │
│  │  Camera      │                      │
│  │  (Webcam/IP) │                      │
│  └──────┬───────┘                      │
│         │                              │
│  ┌──────▼──────────────┐              │
│  │ Nebula Lighthouse   │              │
│  │ IP: 10.1.1.1        │              │
│  │ Public IP: XXX      │              │
│  └──────┬──────────────┘              │
│         │                              │
│  ┌──────▼──────────────┐              │
│  │ MediaMTX RTSP Server│              │
│  │ Port: 8554          │              │
│  └─────────────────────┘              │
│                                         │
│  RTSP Stream: rtsp://10.1.1.1:8554/   │
└─────────┬───────────────────────────────┘
          │
          │ Internet (Nebula VPN - Encrypted)
          │
┌─────────▼───────────────────────────────┐
│  Client Network (Remote Location)        │
│                                         │
│  ┌─────────────────┐                   │
│  │ Nebula Client   │                   │
│  │ IP: 10.1.1.2    │                   │
│  └────────┬────────┘                   │
│           │                            │
│  ┌────────▼──────────────┐             │
│  │ Stream Receiver       │             │
│  │ (FFmpeg Container)    │             │
│  └───────────────────────┘             │
│                                         │
│  Access: rtsp://10.1.1.1:8554/webcam  │
└─────────────────────────────────────────┘
```

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/shivamskr151/nebula_network.git
cd nebula_network
```

### 2. Generate Certificates

```bash
./setup-certs.sh
```

This script will:
- Create the necessary directory structure
- Generate CA certificate
- Generate Lighthouse certificate (IP: 10.1.1.1)
- Generate Client certificate (IP: 10.1.1.2)
- Copy certificates to their respective directories

### 3. Start and Test

```bash
./start-and-test.sh
```

This script will:
- Check Docker daemon status
- Verify certificates exist
- Start all containers (lighthouse, RTSP server, client, stream receiver)
- Run connectivity tests
- Display container status and logs

## 📁 Project Structure

```
nebula_network/
├── readme.md                    # This file
├── setup-certs.sh               # Certificate generation script
├── start-and-test.sh            # Automated startup and testing script
├── ca.key                       # CA private key (keep secure!)
│
├── nebula-lighthouse/          # Lighthouse (server) configuration
│   ├── certs/                   # Lighthouse certificates
│   │   ├── ca.crt
│   │   ├── lighthouse.crt
│   │   └── lighthouse.key
│   ├── configs/
│   │   ├── lighthouse.yml       # Nebula lighthouse config
│   │   └── mediamtx.yml         # RTSP server config
│   ├── docker-compose.yml       # Lighthouse services
│   └── scripts/
│       └── stream-webcam.sh     # Webcam streaming script
│
└── nebula-client/              # Client configuration
    ├── certs/                   # Client certificates
    │   ├── ca.crt
    │   ├── client.crt
    │   └── client.key
    ├── configs/
    │   ├── client.yml           # Nebula client config
    │   └── mediamtx-client.yml  # Client-side MediaMTX config (optional)
    ├── docker-compose.yml       # Client services
    ├── output/                  # Recorded stream output directory
    └── scripts/
        └── receive-stream.sh    # Stream receiving script
```

## ⚙️ Configuration

### Lighthouse Configuration

The lighthouse acts as the central hub for the Nebula network. Key settings in `nebula-lighthouse/configs/lighthouse.yml`:

- **IP Address**: `10.1.1.1/24` (fixed)
- **Port**: `4242` (UDP) - must be accessible from the internet
- **Firewall**: Allows RTSP traffic on port 8554

### Client Configuration

Before starting the client, update `nebula-client/configs/client.yml`:

```yaml
static_host_map:
  "10.1.1.1":
    - "YOUR_LIGHTHOUSE_PUBLIC_IP:4242"  # Replace with your lighthouse's public IP
```

**To find your lighthouse's public IP:**
```bash
curl ifconfig.me
# or
dig +short myip.opendns.com @resolver1.opendns.com
```

### Network Firewall Setup

**On the Lighthouse Network:**
- Open UDP port **4242** on your router/firewall
- Forward it to the lighthouse machine's local IP address
- This allows Nebula clients to connect from the internet

## 📖 Usage

### Starting the Lighthouse

```bash
cd nebula-lighthouse
docker-compose up -d
```

### Starting the Client

```bash
cd nebula-client
docker-compose up -d
```

### Publishing a Camera Stream

**On macOS (using webcam):**
```bash
cd nebula-lighthouse/scripts
./stream-webcam.sh
```

**Using an IP camera or other source:**
Modify the `stream-webcam.sh` script to use your camera source, or use ffmpeg directly:

```bash
ffmpeg -i YOUR_CAMERA_SOURCE -c:v libx264 -f rtsp -rtsp_transport tcp rtsp://127.0.0.1:8554/webcam
```

### Viewing the Stream

**Option 1: Using VLC Player**
```bash
vlc rtsp://10.1.1.1:8554/webcam
```

**Option 2: Using ffplay**
```bash
ffplay rtsp://10.1.1.1:8554/webcam
```

**Option 3: Check recorded files**
The stream receiver automatically records 60-second segments:
```bash
ls -lh nebula-client/output/
```

## 🧪 Testing

### Test Nebula Connectivity

```bash
# From client, ping the lighthouse
docker exec nebula-client ping -c 3 10.1.1.1

# From lighthouse, ping the client
docker exec nebula-lighthouse ping -c 3 10.1.1.2
```

### Test RTSP Connection

```bash
# Test RTSP port accessibility
docker exec nebula-client nc -zv 10.1.1.1 8554
```

### Check Container Status

```bash
docker ps --filter "name=nebula"
```

### View Logs

```bash
# Lighthouse logs
docker logs nebula-lighthouse

# Client logs
docker logs nebula-client

# RTSP server logs
docker logs nebula-rtsp-server

# Stream receiver logs
docker logs nebula-stream-receiver
```

## 🔧 Troubleshooting

### Handshake Timeout

**Symptoms**: Client cannot connect to lighthouse

**Solutions**:
1. Verify lighthouse's public IP is correct in `client.yml`
2. Check UDP port 4242 is open and forwarded on the router
3. Check lighthouse logs: `docker logs nebula-lighthouse`
4. Ensure lighthouse container is running: `docker ps | grep lighthouse`

### RTSP Connection Fails

**Symptoms**: Cannot access RTSP stream

**Solutions**:
1. Verify Nebula connection is established (ping test)
2. Check RTSP server is running: `docker logs nebula-rtsp-server`
3. Ensure camera stream is being published
4. Check firewall rules allow port 8554

### No Video Output

**Symptoms**: Stream connects but no video

**Solutions**:
1. Check camera stream is publishing: `docker logs nebula-rtsp-server`
2. Verify RTSP path is correct: `/webcam`
3. Check stream receiver logs: `docker logs nebula-stream-receiver`
4. Test RTSP URL directly: `ffplay rtsp://10.1.1.1:8554/webcam`

### Certificate Issues

**Symptoms**: Authentication failures

**Solutions**:
1. Regenerate certificates: `./setup-certs.sh`
2. Ensure certificates are in the correct directories
3. Check certificate permissions

### Docker Network Issues

**Symptoms**: Containers cannot communicate

**Solutions**:
1. Ensure Docker network is created: `docker network ls | grep nebula`
2. Restart containers: `docker-compose down && docker-compose up -d`
3. Check container network mode is correct

## 🔒 Security Considerations

- **Encryption**: All traffic is automatically encrypted by Nebula VPN
- **Certificate-Based Auth**: Only devices with valid certificates can connect
- **Firewall Rules**: Configure firewall rules in Nebula configs to restrict access
- **CA Key Security**: Keep `ca.key` secure and never commit it to version control
- **Static IP**: Consider using a static public IP or DDNS for the lighthouse
- **Network Isolation**: Use Nebula firewall rules to limit what services are accessible

## 🛠️ Advanced Configuration

### Custom IP Ranges

To use different IP ranges, modify the certificate generation:

```bash
nebula-cert sign -name lighthouse -ip 192.168.100.1/24
nebula-cert sign -name client -ip 192.168.100.2/24
```

Then update the corresponding config files.

### Multiple Clients

To add more clients:
1. Generate additional client certificates with unique IPs
2. Copy certificates to new client directories
3. Configure each client with the lighthouse's public IP

### Custom RTSP Configuration

Edit `nebula-lighthouse/configs/mediamtx.yml` to customize:
- Stream paths
- Authentication
- Recording settings
- Codec options

## 📝 License

This project is provided as-is for educational and personal use.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📚 Resources

- [Nebula VPN Documentation](https://nebula.defined.net/docs/)
- [MediaMTX Documentation](https://github.com/bluenviron/mediamtx)
- [Nebula GitHub Repository](https://github.com/slackhq/nebula)

## ⚠️ Important Notes

- The `ca.key` file is sensitive and should be kept secure
- Ensure Docker has proper permissions to create network interfaces
- On some systems, you may need to run Docker with `--privileged` mode
- Port forwarding on the router is required for internet access
- The lighthouse must have a public IP or be accessible via port forwarding

---

**Made with ❤️ for secure remote camera access**
