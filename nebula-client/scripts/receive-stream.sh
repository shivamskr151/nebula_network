#!/bin/sh

# Wait for Nebula network to be ready
echo "Waiting for Nebula network..."
sleep 15

echo "📺 Connecting to RTSP stream at rtsp://10.1.1.1:8554/webcam"

# Test connectivity first
echo "Testing connection to 10.1.1.1:8554..."
if nc -zv 10.1.1.1 8554 2>&1; then
    echo "✅ Connection successful!"
else
    echo "❌ Connection failed, retrying in 5 seconds..."
    sleep 5
fi

# Receive and save the stream with verbose logging
ffmpeg -rtsp_transport tcp \
  -loglevel verbose \
  -i rtsp://10.1.1.1:8554/webcam \
  -c:v copy \
  -c:a copy \
  -f mp4 \
  -movflags frag_keyframe+empty_moov \
  -t 60 \
  /output/webcam_stream_$(date +%Y%m%d_%H%M%S).mp4 2>&1

echo "Stream recording completed or failed"

