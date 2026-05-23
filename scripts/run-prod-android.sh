#!/usr/bin/env bash
# Run the Flutter app on Android Emulator against the PRODUCTION backend.
# This is a debug build — useful for poking at the real Microsoft / IDP / API
# endpoints from a fast dev loop, but NOT what ships to Play Store or to a
# physical Android phone. For a release build + install on a connected
# Android device use scripts/deploy-prod-android-device.sh instead.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
EMULATOR="$ANDROID_HOME/emulator/emulator"
ADB="$ANDROID_HOME/platform-tools/adb"

# Entra ID / Azure AD app registration "Application (client) ID".
# Passed explicitly here rather than relying on the default in
# lib/core/data/sync/onedrive_config.dart so a future change to that default
# can't silently leak into prod runs.
ONEDRIVE_CLIENT_ID="3056e225-6965-4c36-8542-db02f614e084"

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

echo "==> Running Flutter app against PRODUCTION environment (debug build)"
echo "    IDP: https://idp.homemademessage.com"
echo "    API: https://api.homemademessage.com/v1"
echo ""

flutter run \
  -d emulator \
  --dart-define=API_ENV=production \
  --dart-define=ONEDRIVE_CLIENT_ID="$ONEDRIVE_CLIENT_ID"
