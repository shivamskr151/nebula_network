#!/bin/bash

# Script to capture macOS webcam and stream to RTSP server
# This script runs on the macOS host and streams to the RTSP server in the lighthouse container

set -e

RTSP_SERVER="rtsp://127.0.0.1:8554/webcam"
VIDEO_DEVICE="0"  # Default webcam (usually 0 on macOS)
VIDEO_SIZE="1280x720"
FRAMERATE="30"

echo "📹 Starting webcam stream to RTSP server..."
echo "   RTSP Server: $RTSP_SERVER"
echo "   Video Device: $VIDEO_DEVICE"
echo "   Resolution: $VIDEO_SIZE @ ${FRAMERATE}fps"
echo ""
echo "To list available video devices, run:"
echo "   ffmpeg -f avfoundation -list_devices true -i \"\""
echo ""

# Check if RTSP server is accessible
echo "Checking RTSP server availability..."
if ! nc -z 127.0.0.1 8554 2>/dev/null; then
    echo "⚠️  Warning: RTSP server may not be running on port 8554"
    echo "   Make sure the lighthouse container with RTSP server is running"
    echo "   Run: cd nebula-lighthouse && docker-compose up -d"
    echo ""
fi

# Stream webcam to RTSP server using avfoundation (macOS native)
echo "Starting ffmpeg stream..."
ffmpeg -f avfoundation \
    -framerate $FRAMERATE \
    -video_size $VIDEO_SIZE \
    -i "$VIDEO_DEVICE:none" \
    -c:v libx264 \
    -preset ultrafast \
    -tune zerolatency \
    -b:v 2000k \
    -maxrate 2000k \
    -bufsize 4000k \
    -g 30 \
    -f rtsp \
    -rtsp_transport tcp \
    "$RTSP_SERVER" \
    2>&1 | while IFS= read -r line; do
        echo "[ffmpeg] $line"
    done

