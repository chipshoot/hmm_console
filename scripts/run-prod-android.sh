#!/usr/bin/env bash
# Run the Flutter app on Android emulator against production environment
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
EMULATOR="$ANDROID_HOME/emulator/emulator"
ADB="$ANDROID_HOME/platform-tools/adb"

# Check if an emulator is already running
RUNNING_DEVICE=$("$ADB" devices 2>/dev/null | grep -w "device" | head -1 | awk '{print $1}' || true)

if [ -z "$RUNNING_DEVICE" ]; then
  echo "==> No running Android emulator found. Starting one..."

  # List available AVDs and pick the first one
  AVD_NAME=$("$EMULATOR" -list-avds 2>/dev/null | head -1)
  if [ -z "$AVD_NAME" ]; then
    echo "ERROR: No Android AVDs found. Create one with Android Studio first."
    exit 1
  fi

  echo "==> Booting AVD: $AVD_NAME"
  "$EMULATOR" -avd "$AVD_NAME" -no-snapshot-load &
  EMULATOR_PID=$!

  echo "==> Waiting for emulator to boot..."
  "$ADB" wait-for-device
  # Wait until boot animation finishes
  while [ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" != "1" ]; do
    sleep 2
  done
  echo "==> Emulator booted."
else
  echo "==> Using running emulator: $RUNNING_DEVICE"
fi

echo "==> Running Flutter app against PRODUCTION environment"
echo "    IDP: https://idp.homemademessage.com"
echo "    API: https://api.homemademessage.com/api/v1"
echo ""

flutter run \
  -d emulator \
  --dart-define=API_ENV=production
