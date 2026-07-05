#!/usr/bin/env bash
# One-shot build + install + LAUNCH of a RELEASE iOS binary against the
# PRODUCTION backend on the connected iPhone, via `flutter run --release`.
#
# This is the flow verified working on iOS 26.5 in this project (Developer
# Mode on + iOS deployment target >= 15.5). It complements the two existing
# helpers:
#   - scripts/run-prod-ios.sh          -> DEBUG build on the iOS *Simulator*
#   - scripts/deploy-prod-ios-device.sh -> RELEASE build + devicectl install
#                                          on device, but does NOT launch
# Use this one when you want the app built, installed, AND started on a
# physical iPhone in a single command.
#
# The whole point of this script is the --dart-define=API_ENV=production flag:
# without it the app defaults to the 'development' config and points the IdP /
# API at http://localhost, which a physical phone cannot reach ("No internet
# connection" on login).
#
# Prerequisites (one-time):
#   1. iPhone: Settings -> Privacy & Security -> Developer Mode -> On (reboots)
#   2. Cable connected, phone unlocked, "Trust this computer" accepted
#   3. Signing team configured in Xcode (Runner target -> Signing)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# Entra ID / Azure AD app registration "Application (client) ID".
# Passed explicitly so a future edit to the default in
# lib/core/data/sync/onedrive_config.dart can't silently change prod builds.
ONEDRIVE_CLIENT_ID="3056e225-6965-4c36-8542-db02f614e084"

echo "==> Locating a connected physical iPhone..."
DEVICE_ID=$(flutter devices --machine 2>/dev/null | python3 -c "
import json, sys
try:
    devices = json.load(sys.stdin)
except (json.JSONDecodeError, ValueError):
    sys.exit(1)
for d in devices:
    if d.get('targetPlatform', '').startswith('ios') and not d.get('emulator', True):
        print(d['id'])
        sys.exit(0)
sys.exit(1)
" 2>/dev/null || true)

if [ -z "$DEVICE_ID" ]; then
  echo ""
  echo "ERROR: No connected physical iPhone found."
  echo "  - Cable plugged in, phone unlocked, 'Trust this computer' accepted?"
  echo "  - Developer Mode on (Settings -> Privacy & Security -> Developer Mode)?"
  echo "  - 'flutter devices' should list your iPhone."
  exit 1
fi

echo "==> RELEASE build + install + launch against PRODUCTION on: $DEVICE_ID"
echo "    IDP: https://idp.homemademessage.com"
echo "    API: https://api.homemademessage.com/v1"
echo ""

flutter run --release \
  -d "$DEVICE_ID" \
  --dart-define=API_ENV=production \
  --dart-define=ONEDRIVE_CLIENT_ID="$ONEDRIVE_CLIENT_ID"
