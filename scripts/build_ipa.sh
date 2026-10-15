#!/bin/bash
# Archives MTDBuddy unsigned and produces ~/Desktop/MTDBuddy.ipa for AltStore/SideStore.
set -euo pipefail
cd "$(dirname "$0")/.."

SCHEME="MTDBuddy"
ARCHIVE_PATH="build/MTDBuddy.xcarchive"
APP_NAME="MTDBuddy.app"
PAYLOAD_DIR="build/Payload"
IPA_PATH="$HOME/Desktop/MTDBuddy.ipa"

./scripts/generate.sh

rm -rf build
mkdir -p build

xcodebuild -project MTDBuddy.xcodeproj -scheme "$SCHEME" -configuration Release -sdk iphoneos \
  -archivePath "$ARCHIVE_PATH" archive CODE_SIGNING_ALLOWED=NO

APP_PATH="$ARCHIVE_PATH/Products/Applications/$APP_NAME"
if [ ! -d "$APP_PATH" ]; then
  echo "Archive succeeded but $APP_PATH wasn't found." >&2
  exit 1
fi

rm -rf "$PAYLOAD_DIR"
mkdir -p "$PAYLOAD_DIR"
cp -R "$APP_PATH" "$PAYLOAD_DIR/"

if command -v ldid >/dev/null 2>&1; then
  echo "Fake-signing entitlements with ldid so the App Group survives re-signing..."
  ldid -S"MTDBuddy/MTDBuddy.entitlements" "$PAYLOAD_DIR/$APP_NAME/MTDBuddy"
  PLUGIN_DIR="$PAYLOAD_DIR/$APP_NAME/PlugIns"
  if [ -d "$PLUGIN_DIR" ]; then
    for ext in "$PLUGIN_DIR"/*.appex; do
      [ -d "$ext" ] || continue
      name=$(basename "$ext" .appex)
      ldid -S"MTDBuddyWidget/MTDBuddyWidget.entitlements" "$ext/$name" || true
    done
  fi
else
  echo "ldid not found (brew install ldid) — the App Group entitlement will be dropped when AltStore re-signs this.
  The app and widget still work; they'll just fall back to the widget's own 'nearest stop' configuration instead of sharing favorites." >&2
fi

rm -f "$IPA_PATH"
(cd build && zip -qr "MTDBuddy.ipa" Payload)
mv build/MTDBuddy.ipa "$IPA_PATH"
echo "IPA written to $IPA_PATH"
