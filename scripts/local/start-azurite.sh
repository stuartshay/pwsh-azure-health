#!/bin/bash
# Start Azurite for local Azure Storage emulation

set -e

# Use workspace .azurite directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
AZURITE_DIR="$WORKSPACE_ROOT/.azurite"

# Create Azurite data directory if it doesn't exist
if [ ! -d "$AZURITE_DIR" ]; then
    echo "Creating Azurite data directory: $AZURITE_DIR"
    mkdir -p "$AZURITE_DIR"
fi

echo "Starting Azurite Azure Storage Emulator..."
echo "Data directory: $AZURITE_DIR"
echo ""
echo "Endpoints:"
echo "  Blob:  http://127.0.0.1:10000"
echo "  Queue: http://127.0.0.1:10001"
echo "  Table: http://127.0.0.1:10002"
echo ""

# Start Azurite
azurite \
  --silent \
  --location "$AZURITE_DIR" \
  --debug "$AZURITE_DIR/debug.log" \
  --blobHost 0.0.0.0 \
  --queueHost 0.0.0.0 \
  --tableHost 0.0.0.0
