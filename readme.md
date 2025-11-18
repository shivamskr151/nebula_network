# Cross-Network Camera Access with Nebula VPN

This guide explains how to access a camera on the **Lighthouse Network** from a **Client Network** using Nebula VPN.

## Architecture

```
┌─────────────────────────────────┐
│  Lighthouse Network              │
│  (Camera Location)                │
│                                   │
│  ┌──────────────┐                │
│  │  Camera      │                │
│  │  (Webcam/IP) │                │
│  └──────┬───────┘                │
│         │                        │
│  ┌──────▼──────────┐             │
│  │ Nebula Lighthouse│             │
│  │ IP: 10.1.1.1    │             │
│  │ Public IP: XXX  │             │
│  └─────────────────┘             │
│         │                        │
│  RTSP Server: 10.1.1.1:8554      │
└─────────┼────────────────────────┘
          │
          │ Internet (Nebula VPN)
          │
┌─────────▼────────────────────────┐
│  Client Network                  │
│  (Remote Location)               │
│                                   │
│  ┌─────────────────┐             │
│  │ Nebula Client   │             │
│  │ IP: 10.1.1.2    │             │
│  └────────┬────────┘             │
│           │                       │
│  ┌────────▼────────┐             │
│  │ Stream Receiver │             │
│  │ or VLC Player   │             │
│  └─────────────────┘             │
│                                   │
│  Access: rtsp://10.1.1.1:8554   │
└───────────────────────────────────┘
```

## Setup Instructions

### On Lighthouse Network (Camera Location)

1. **Ensure Lighthouse is running:**
   ```bash
   cd nebula-lighthouse
   docker-compose up -d
   ```

2. **Find your Public IP address:**
   ```bash
   curl ifconfig.me
   # or
   dig +short myip.opendns.com @resolver1.opendns.com
   ```

3. **Configure firewall/router:**
   - Open UDP port **4242** on your router/firewall
   - Forward it to the lighthouse machine's local IP
   - This allows Nebula clients to connect from the internet

4. **Start camera stream:**
   ```bash
   cd nebula-lighthouse/scripts
   ./stream-webcam.sh
   ```

### On Client Network (Remote Location)

1. **Update client configuration:**
   - Edit `nebula-client/configs/client.yml`
   - Replace `192.168.3.156:4242` with your lighthouse's **PUBLIC IP:4242**
   - Example: `"123.45.67.89:4242"`

2. **Start client:**
   ```bash
   cd nebula-client
   docker-compose up -d
   ```

3. **Verify connection:**
   ```bash
   docker logs nebula-client | grep "Handshake"
   # Should show successful handshake
   ```

4. **Access camera stream:**
   - RTSP URL: `rtsp://10.1.1.1:8554/webcam`
   - Use VLC, ffplay, or the stream-receiver container

## Testing

### From Client Network:

```bash
# Test Nebula connectivity
docker exec nebula-client ping -c 3 10.1.1.1

# Test RTSP connection
docker exec nebula-stream-receiver sh -c "timeout 5 nc -zv 10.1.1.1 8554"

# View stream with VLC (on client laptop)
vlc rtsp://10.1.1.1:8554/webcam
```

## Troubleshooting

1. **Handshake timeout:**
   - Check lighthouse's public IP is correct
   - Verify UDP port 4242 is open on router
   - Check lighthouse logs: `docker logs nebula-lighthouse`

2. **RTSP connection fails:**
   - Verify Nebula connection is established
   - Check firewall rules allow port 8554
   - Ensure camera stream is running on lighthouse

3. **No video:**
   - Check camera stream is publishing: `docker logs nebula-rtsp-server`
   - Verify RTSP path is correct: `/webcam`

## Security Notes

- Nebula encrypts all traffic automatically
- Only devices with valid certificates can connect
- Firewall rules control what services are accessible
- Consider using a static public IP or DDNS for the lighthouse

