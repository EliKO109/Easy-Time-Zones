#!/usr/bin/env bash
# Easy Time Zones – DMG Packager
# Run this locally after doing an Xcode Archive > Copy App
#
# Usage:
#   ./package.sh "path/to/Easy Time Zones.app"
#
# Output: EasyTimeZones-<version>.dmg in the current directory

set -euo pipefail

APP_PATH="$1"
APP_NAME="Easy Time Zones"

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
  echo "Usage: ./package.sh \"path/to/Easy Time Zones.app\""
  exit 1
fi

# Grab the version from the .app bundle
VERSION=$(defaults read "${APP_PATH}/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "1.0.0")
DMG_NAME="EasyTimeZones-${VERSION}.dmg"
TMP_DIR=$(mktemp -d)
STAGING="${TMP_DIR}/${APP_NAME}"

echo ""
echo "📦  DMG Packager – Easy Time Zones"
echo "─────────────────────────────────────"
echo "    App:     ${APP_PATH}"
echo "    Version: ${VERSION}"
echo "    Output:  ${DMG_NAME}"
echo ""

# ── 1. Create staging folder ──────────────────────────────────────────────────
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "${STAGING}/Applications"

# ── 2. Create the DMG ─────────────────────────────────────────────────────────
echo "▶  Building DMG…"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  "$DMG_NAME"

# ── 3. Generate SHA-256 checksum ──────────────────────────────────────────────
SHA_FILE="${DMG_NAME}.sha256"
shasum -a 256 "$DMG_NAME" > "$SHA_FILE"
echo "✅  Checksum: ${SHA_FILE}"

# ── 4. Clean up ───────────────────────────────────────────────────────────────
rm -rf "$TMP_DIR"

echo ""
echo "✅  Created: ${DMG_NAME}"
echo "    Upload both ${DMG_NAME} AND ${SHA_FILE} to your GitHub Release assets."
echo ""
