#!/bin/bash
set -e

# Get the first available mobile device (Android/iOS)
# Filter out Web and Desktop (Linux, Windows, macOS) devices if possible, or just pick the first valid mobile one.
# flutter devices output format: Name • ID • ...
DEVICE_ID=$(flutter devices | grep "•" | grep -v "Web" | grep -v "Linux" | grep -v "macOS" | grep -v "Windows" | head -n 1 | awk -F " • " '{print $2}')

if [ -z "$DEVICE_ID" ]; then
  echo "No suitable mobile device found for integration tests."
  # If we want to allow failure when no device is present (e.g. CI without emulator), exit 0?
  # But pre-push typically implies we want to verify.
  exit 1
fi

echo "Running integration tests on device: $DEVICE_ID"
flutter test integration_test -d "$DEVICE_ID"
