#!/usr/bin/env bash
# Build a RELEASE iOS binary against the PRODUCTION backend, then install it
# on the connected iPhone via `xcrun devicectl`. devicectl is used instead of
# `flutter run --release` because Flutter's install path is broken on iOS 26.x
# (verified in this project's session log) — devicectl is Apple's supported
# CLI replacement for ios-deploy.
#
# Prerequisites (one-time):
#   1. Open ios/Runner.xcworkspace in Xcode (workspace, not project)
#   2. Runner target → Signing & Capabilities → set Team → leave automatic
#      provisioning on
#   3. Connect the iPhone via USB, unlock it, tap "Trust" when prompted
#   4. In Xcode's device window once, click your phone so Xcode "prepares" it
#      (registers the UDID with your provisioning profile)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# Entra ID / Azure AD app registration "Application (client) ID".
# Passed explicitly so a future edit to the default in
# lib/core/data/sync/onedrive_config.dart can't silently change prod builds.
ONEDRIVE_CLIENT_ID="3056e225-6965-4c36-8542-db02f614e084"

echo "==> Production release build (--release, AOT-compiled, no observatory)"
echo "    IDP: https://idp.homemademessage.com"
echo "    API: https://api.homemademessage.com/v1"
echo ""

flutter build ios --release \
  --dart-define=API_ENV=production \
  --dart-define=ONEDRIVE_CLIENT_ID="$ONEDRIVE_CLIENT_ID"

# Pick the first paired iPhone. Two `xcrun devicectl` quirks to navigate:
#
#   1. `--json-output -` does NOT route JSON to stdout (despite the
#      manpage hinting that `-` is the stdout sentinel). Verified on
#      macOS Tahoe + Xcode 17: it silently emits the human-readable
#      table to stdout and writes nothing. Route through a temp file.
#
#   2. `connectionProperties.tunnelState` is `"disconnected"` for a
#      healthy idle device sitting on USB and only flips to
#      `"connected"` mid-install. Don't gate on it. The right readiness
#      signal is `pairingState == "paired"` alone, optionally combined
#      with `hardwareProperties.deviceType == "iPhone"` (so a paired
#      iPad on the same Mac doesn't get picked).
DEVICE_JSON=$(mktemp /tmp/devicectl-XXXXXX.json)
trap 'rm -f "$DEVICE_JSON"' EXIT
xcrun devicectl list devices --json-output "$DEVICE_JSON" >/dev/null 2>&1 || true

DEVICE_ID=$(python3 -c "
import json, sys
try:
    with open('$DEVICE_JSON') as f:
        data = json.load(f)
except (OSError, json.JSONDecodeError):
    sys.exit(1)
for d in data.get('result', {}).get('devices', []):
    conn = d.get('connectionProperties', {}) or {}
    hw   = d.get('hardwareProperties', {}) or {}
    if conn.get('pairingState') == 'paired' and hw.get('deviceType') == 'iPhone':
        print(d['identifier'])
        sys.exit(0)
sys.exit(1)
" 2>/dev/null || true)

if [ -z "$DEVICE_ID" ]; then
  echo ""
  echo "ERROR: No paired iPhone found via xcrun devicectl."
  echo "  - Cable plugged in?"
  echo "  - Phone unlocked + 'Trust this computer' accepted?"
  echo "  - Xcode → Devices and Simulators → your phone shows up clean?"
  echo ""
  echo "Run 'xcrun devicectl list devices' to inspect the full state."
  exit 1
fi

echo ""
echo "==> Installing on iPhone: $DEVICE_ID"
xcrun devicectl device install app \
  --device "$DEVICE_ID" \
  build/ios/iphoneos/Runner.app

echo ""
echo "==> Done. Launch the app on the iPhone manually (devicectl install"
echo "    leaves the launch to the user — pass --launch if you want it"
echo "    auto-started)."
