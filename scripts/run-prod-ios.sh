#!/usr/bin/env bash
# Run the Flutter app on iOS simulator against production environment
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

echo "==> Checking for running iOS Simulator..."
if ! pgrep -x "Simulator" > /dev/null 2>&1; then
  echo "==> Booting iOS Simulator..."
  open -a Simulator
  # Wait for simulator to be ready
  sleep 5
fi

# Find a booted device, or boot the first available iPhone
BOOTED_DEVICE=$(xcrun simctl list devices booted --json 2>/dev/null | \
  python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    for d in devices:
        if d['state'] == 'Booted':
            print(d['udid'])
            sys.exit(0)
" 2>/dev/null || true)

if [ -z "$BOOTED_DEVICE" ]; then
  echo "==> No booted simulator found. Booting first available iPhone..."
  DEVICE_UDID=$(xcrun simctl list devices available --json | \
    python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    if 'iOS' in runtime:
        for d in devices:
            if 'iPhone' in d['name'] and d['isAvailable']:
                print(d['udid'])
                sys.exit(0)
sys.exit(1)
")
  xcrun simctl boot "$DEVICE_UDID"
  open -a Simulator
  sleep 3
  BOOTED_DEVICE="$DEVICE_UDID"
fi

echo "==> Using simulator: $BOOTED_DEVICE"
echo "==> Running Flutter app against PRODUCTION environment"
echo "    IDP: https://idp.homemademessage.com"
echo "    API: https://api.homemademessage.com/api/v1"
echo ""

flutter run \
  -d "$BOOTED_DEVICE" \
  --dart-define=API_ENV=production
