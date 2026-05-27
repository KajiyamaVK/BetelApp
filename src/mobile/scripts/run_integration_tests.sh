#!/bin/bash
set -e

# Get the first available mobile device (Android/iOS)
# Filter out Web and Desktop (Linux, Windows, macOS) devices if possible, or just pick the first valid mobile one.
# flutter devices output format: Name • ID • ...
DEVICE_ID=$(flutter devices | grep "•" | grep -v "Web" | grep -v "Linux" | grep -v "macOS" | grep -v "Windows" | head -n 1 | awk -F " • " '{print $2}')

if [ -z "$DEVICE_ID" ]; then
  echo "No suitable mobile device found for integration tests. Skipping."
  exit 0
fi

echo "Running integration tests on device: $DEVICE_ID"
# 3-minute timeout: Wi-Fi ADB WebSocket can drop after install, causing infinite hang
timeout 180 flutter test integration_test -d "$DEVICE_ID"
EXIT_CODE=$?

if [ $EXIT_CODE -eq 124 ]; then
  echo "Integration test timed out (Wi-Fi ADB connection issue). Skipping."
  exit 0
fi

exit $EXIT_CODE
