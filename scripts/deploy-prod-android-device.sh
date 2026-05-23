#!/usr/bin/env bash
# Build a RELEASE Android APK against the PRODUCTION backend, then install
# it on the connected Android device via adb.
#
# Prerequisites:
#   1. Android device connected via USB
#   2. USB debugging enabled (Settings → Developer options → USB debugging)
#   3. Computer authorised on the device (RSA fingerprint prompt accepted)
#
# Signing: android/app/build.gradle.kts currently has the release build
# wired to `signingConfigs.getByName("debug")` (see the TODO comment in
# that file). That means this script produces an APK signed with your
# local debug keystore — installable on YOUR personal devices via adb,
# but not distributable via Play Store or sideloadable to other people's
# phones. When you set up a proper release keystore later, this script
# stays unchanged — only the Gradle config needs updating.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
ADB="$ANDROID_HOME/platform-tools/adb"

# Entra ID / Azure AD app registration "Application (client) ID".
# Passed explicitly so a future edit to the default in
# lib/core/data/sync/onedrive_config.dart can't silently change prod builds.
ONEDRIVE_CLIENT_ID="3056e225-6965-4c36-8542-db02f614e084"

# Pick the first physical device — anything NOT starting with `emulator-`.
# `adb devices` output format: `<serial>\t<state>` one device per line after
# a "List of devices attached" header.
PHYSICAL_DEVICE=$("$ADB" devices 2>/dev/null \
  | awk '/^[A-Za-z0-9].*\tdevice$/ && $1 !~ /^emulator-/ { print $1; exit }' \
  || true)

if [ -z "$PHYSICAL_DEVICE" ]; then
  echo "ERROR: No connected Android device found (excluding emulators)."
  echo "  - Cable plugged in?"
  echo "  - USB debugging enabled? (Settings → Developer options)"
  echo "  - 'Allow USB debugging' prompt accepted on the phone?"
  echo ""
  echo "Run '$ADB devices' to see what's attached."
  exit 1
fi

echo "==> Production release build (--release, AOT-compiled, R8-shrunk)"
echo "    IDP: https://idp.homemademessage.com"
echo "    API: https://api.homemademessage.com/v1"
echo "    Target device: $PHYSICAL_DEVICE"
echo ""

flutter build apk --release \
  --dart-define=API_ENV=production \
  --dart-define=ONEDRIVE_CLIENT_ID="$ONEDRIVE_CLIENT_ID"

APK_PATH="$PROJECT_DIR/build/app/outputs/flutter-apk/app-release.apk"
if [ ! -f "$APK_PATH" ]; then
  echo "ERROR: Expected APK not found at $APK_PATH"
  exit 1
fi

echo ""
echo "==> Installing on $PHYSICAL_DEVICE"
# -r reinstalls (replacing previous app), -t allows test apks (debug-signed
# release APKs count as "test" to adb's strict mode on newer Android).
"$ADB" -s "$PHYSICAL_DEVICE" install -r -t "$APK_PATH"

echo ""
echo "==> Done. Launch the app from your device's launcher."
