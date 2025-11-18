#!/bin/bash

set -e

# Get the absolute path of the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$SCRIPT_DIR"

# Check if Docker daemon is running
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        echo "❌ Error: Docker daemon is not running."
        echo ""
        echo "Please start Docker Desktop or Docker daemon and try again."
        echo "On macOS, you can start Docker Desktop from Applications."
        exit 1
    fi
}

# Check if certificates exist
check_certificates() {
    local lighthouse_certs=(
        "$BASE_DIR/nebula-lighthouse/certs/ca.crt"
        "$BASE_DIR/nebula-lighthouse/certs/lighthouse.crt"
        "$BASE_DIR/nebula-lighthouse/certs/lighthouse.key"
    )
    local client_certs=(
        "$BASE_DIR/nebula-client/certs/ca.crt"
        "$BASE_DIR/nebula-client/certs/client.crt"
        "$BASE_DIR/nebula-client/certs/client.key"
    )
    
    local missing=0
    
    echo "🔍 Checking certificates..."
    for cert in "${lighthouse_certs[@]}"; do
        if [ ! -f "$cert" ]; then
            echo "   ❌ Missing: $cert"
            missing=1
        fi
    done
    
    for cert in "${client_certs[@]}"; do
        if [ ! -f "$cert" ]; then
            echo "   ❌ Missing: $cert"
            missing=1
        fi
    done
    
    if [ $missing -eq 1 ]; then
        echo ""
        echo "❌ Error: Required certificates are missing!"
        echo ""
        echo "Please run the certificate setup script first:"
        echo "   ./setup-certs.sh"
        echo ""
        echo "Note: You need 'nebula-cert' tool installed to generate certificates."
        exit 1
    fi
    
    echo "✅ All certificates found"
}

# Wait for container to be running
wait_for_container() {
    local container_name=$1
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
            # Check if container is actually running (not just created)
            local status=$(docker inspect -f '{{.State.Status}}' "$container_name" 2>/dev/null)
            if [ "$status" = "running" ]; then
                return 0
            fi
        fi
        attempt=$((attempt + 1))
        sleep 1
    done
    
    return 1
}

# Check container status and show logs if failed
check_container_status() {
    local container_name=$1
    local status=$(docker inspect -f '{{.State.Status}}' "$container_name" 2>/dev/null)
    
    if [ "$status" != "running" ]; then
        echo "❌ Container $container_name is not running (status: ${status:-not found})"
        echo ""
        echo "Last 10 lines of logs:"
        docker logs --tail 10 "$container_name" 2>&1 || echo "   No logs available"
        return 1
    fi
    return 0
}

# Ensure container is fully ready (network namespace initialized)
wait_for_container_ready() {
    local container_name=$1
    local max_attempts=10
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        # Check if container is running
        local status=$(docker inspect -f '{{.State.Status}}' "$container_name" 2>/dev/null)
        if [ "$status" = "running" ]; then
            # Try to inspect the network namespace to ensure it's ready
            if docker exec "$container_name" true > /dev/null 2>&1; then
                return 0
            fi
        fi
        attempt=$((attempt + 1))
        sleep 1
    done
    
    return 1
}

# Clean up any existing containers to avoid conflicts
cleanup_containers() {
    echo "🧹 Cleaning up any existing containers..."
    cd "$BASE_DIR/nebula-lighthouse"
    docker-compose down 2>/dev/null || true
    
    cd "$BASE_DIR/nebula-client"
    docker-compose down 2>/dev/null || true
    
    # Remove any orphaned containers
    docker rm -f nebula-lighthouse nebula-rtsp-server nebula-client nebula-stream-receiver 2>/dev/null || true
    echo "✅ Cleanup complete"
    echo ""
}

echo "🔍 Checking Docker daemon..."
check_docker
echo "✅ Docker daemon is running"
echo ""

check_certificates
echo ""

cleanup_containers

echo "🚀 Starting Nebula Lighthouse container..."
cd "$BASE_DIR/nebula-lighthouse"
docker-compose up -d lighthouse

echo "⏳ Waiting for lighthouse to be running..."
if wait_for_container "nebula-lighthouse"; then
    echo "✅ Lighthouse container is running"
else
    echo "❌ Lighthouse container failed to start"
    check_container_status "nebula-lighthouse"
    exit 1
fi

echo "⏳ Waiting for lighthouse network namespace to be ready..."
if wait_for_container_ready "nebula-lighthouse"; then
    echo "✅ Lighthouse container is fully ready"
    sleep 1  # Small additional delay to ensure network namespace is stable
else
    echo "⚠️  Lighthouse container may not be fully ready, but continuing..."
fi

echo "🚀 Starting RTSP server container..."
# Verify lighthouse container exists and is running
if ! docker ps --format "{{.Names}}" | grep -q "^nebula-lighthouse$"; then
    echo "❌ Lighthouse container is not running"
    exit 1
fi

# Remove any existing rtsp-server container first
docker rm -f nebula-rtsp-server 2>/dev/null || true

# Start RTSP server using docker run directly to avoid docker-compose network namespace issues
# Get the absolute path to mediamtx.yml
MEDIAMTX_CONFIG="$BASE_DIR/nebula-lighthouse/configs/mediamtx.yml"
if [ ! -f "$MEDIAMTX_CONFIG" ]; then
    echo "❌ MediaMTX config file not found: $MEDIAMTX_CONFIG"
    exit 1
fi

echo "   Using MediaMTX config: $MEDIAMTX_CONFIG"
docker run -d \
    --name nebula-rtsp-server \
    --network container:nebula-lighthouse \
    -v "$MEDIAMTX_CONFIG:/mediamtx.yml:ro" \
    --restart unless-stopped \
    bluenviron/mediamtx:latest

echo "⏳ Waiting for RTSP server to be running..."
sleep 2
if wait_for_container "nebula-rtsp-server"; then
    echo "✅ RTSP server container is running"
else
    echo "⚠️  RTSP server container may not be running (checking status...)"
    check_container_status "nebula-rtsp-server"
    
    # If it failed, try one more time with a longer wait
    RTSP_STATUS=$(docker inspect -f '{{.State.Status}}' nebula-rtsp-server 2>/dev/null)
    if [ "$RTSP_STATUS" != "running" ]; then
        echo ""
        echo "Retrying RTSP server startup..."
        docker rm -f nebula-rtsp-server 2>/dev/null || true
        sleep 2
        docker run -d \
            --name nebula-rtsp-server \
            --network container:nebula-lighthouse \
            -v "$MEDIAMTX_CONFIG:/mediamtx.yml:ro" \
            --restart unless-stopped \
            bluenviron/mediamtx:latest
        sleep 3
        if wait_for_container "nebula-rtsp-server"; then
            echo "✅ RTSP server container started on retry"
        else
            echo "❌ RTSP server failed to start after retry"
            check_container_status "nebula-rtsp-server"
        fi
    fi
fi

echo ""
echo "🚀 Starting Nebula Client container..."
cd "$BASE_DIR/nebula-client"
docker-compose up -d nebula-client

echo "⏳ Waiting for client to be running..."
if wait_for_container "nebula-client"; then
    echo "✅ Client container is running"
    sleep 2
else
    echo "❌ Client container failed to start"
    check_container_status "nebula-client"
    exit 1
fi

echo "🚀 Starting stream receiver container..."
# Verify client container exists and is running
if ! docker ps --format "{{.Names}}" | grep -q "^nebula-client$"; then
    echo "❌ Client container is not running"
    exit 1
fi

# Remove any existing stream-receiver container first
docker rm -f nebula-stream-receiver 2>/dev/null || true

# Get absolute paths for volumes
CLIENT_OUTPUT="$BASE_DIR/nebula-client/output"
CLIENT_SCRIPTS="$BASE_DIR/nebula-client/scripts"
mkdir -p "$CLIENT_OUTPUT"

echo "   Using output directory: $CLIENT_OUTPUT"
echo "   Using scripts directory: $CLIENT_SCRIPTS"

# Start stream receiver using docker run directly
# Override entrypoint to use /bin/sh (ffmpeg image defaults to ffmpeg)
docker run -d \
    --name nebula-stream-receiver \
    --network container:nebula-client \
    --entrypoint /bin/sh \
    -v "$CLIENT_OUTPUT:/output" \
    -v "$CLIENT_SCRIPTS:/scripts:ro" \
    --restart unless-stopped \
    jrottenberg/ffmpeg:4.4-alpine \
    /scripts/receive-stream.sh

echo "⏳ Waiting for stream receiver to be running..."
sleep 2
if wait_for_container "nebula-stream-receiver"; then
    echo "✅ Stream receiver container is running"
else
    echo "⚠️  Stream receiver container may not be running (checking status...)"
    check_container_status "nebula-stream-receiver"
fi

echo ""
echo "📊 Container Status:"
docker ps --filter "name=nebula" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "🔍 Testing connectivity..."
echo ""

echo "1. Checking if containers are running:"
if docker ps | grep -q "nebula-lighthouse"; then
    echo "   ✅ nebula-lighthouse is running"
else
    echo "   ❌ nebula-lighthouse is not running"
fi

if docker ps | grep -q "nebula-client"; then
    echo "   ✅ nebula-client is running"
else
    echo "   ❌ nebula-client is not running"
fi

echo ""
echo "2. Checking Nebula network interfaces:"
echo "   Lighthouse container:"
docker exec nebula-lighthouse ip addr show nebula1 2>/dev/null || echo "   ⚠️  nebula1 interface not found yet"

echo "   Client container:"
docker exec nebula-client ip addr show nebula1 2>/dev/null || echo "   ⚠️  nebula1 interface not found yet"

echo ""
echo "3. Testing ping from client to lighthouse (10.1.1.1):"
docker exec nebula-client ping -c 3 10.1.1.1 2>&1 || echo "   ⚠️  Ping failed - containers may still be connecting"

echo ""
echo "4. Testing ping from lighthouse to client (10.1.1.2):"
docker exec nebula-lighthouse ping -c 3 10.1.1.2 2>&1 || echo "   ⚠️  Ping failed - containers may still be connecting"

echo ""
echo "5. Testing RTSP connectivity:"
echo "   Testing connection from client to RTSP server (10.1.1.1:8554)..."
if docker exec nebula-client nc -zv 10.1.1.1 8554 2>&1 | grep -q "succeeded"; then
    echo "   ✅ RTSP port 8554 is reachable"
else
    echo "   ⚠️  RTSP port 8554 is not reachable (Nebula may still be connecting)"
fi

echo ""
echo "6. Checking stream receiver status:"
if docker ps | grep -q "nebula-stream-receiver"; then
    echo "   ✅ Stream receiver is running"
    echo "   Checking stream receiver logs (last 10 lines):"
    docker logs --tail 10 nebula-stream-receiver 2>&1 | sed 's/^/   /'
    
    # Check if output files exist
    OUTPUT_COUNT=$(ls -1 "$BASE_DIR/nebula-client/output"/*.mp4 2>/dev/null | wc -l | tr -d ' ')
    if [ "$OUTPUT_COUNT" -gt 0 ]; then
        echo ""
        echo "   📁 Output files found: $OUTPUT_COUNT"
        ls -lh "$BASE_DIR/nebula-client/output"/*.mp4 2>/dev/null | tail -3 | sed 's/^/   /'
    else
        echo ""
        echo "   ⚠️  No output files yet (stream may not be published)"
        echo "   To publish a stream, run:"
        echo "      cd $BASE_DIR/nebula-lighthouse/scripts"
        echo "      ./stream-webcam.sh"
    fi
else
    echo "   ❌ Stream receiver is not running"
    echo "   Checking why..."
    docker logs --tail 20 nebula-stream-receiver 2>&1 | sed 's/^/   /'
fi

echo ""
echo "7. Checking Nebula logs:"
echo "   Lighthouse logs (last 5 lines):"
docker logs --tail 5 nebula-lighthouse 2>&1 | sed 's/^/   /' || echo "   No logs available"

echo "   Client logs (last 5 lines):"
docker logs --tail 5 nebula-client 2>&1 | sed 's/^/   /' || echo "   No logs available"

echo ""
echo "✅ Done!"
echo ""
echo "📝 Next steps:"
echo "   1. If no stream is published, start the webcam stream:"
echo "      cd $BASE_DIR/nebula-lighthouse/scripts"
echo "      ./stream-webcam.sh"
echo ""
echo "   2. Check stream receiver logs:"
echo "      docker logs -f nebula-stream-receiver"
echo ""
echo "   3. View output files:"
echo "      ls -lh $BASE_DIR/nebula-client/output/"
echo ""
echo "   4. If pings failed, wait a few more seconds and check logs:"
echo "      docker logs nebula-lighthouse"
echo "      docker logs nebula-client"

