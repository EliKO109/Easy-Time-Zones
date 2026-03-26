#!/usr/bin/env bash
# Easy Time Zones – one-liner installer
# Usage:
#   curl -fsSLO https://raw.githubusercontent.com/EliKO109/Easy-Time-Zones/main/install.sh && bash install.sh

set -euo pipefail

APP_NAME="Easy Time Zones"
REPO="EliKO109/Easy-Time-Zones"
INSTALL_DIR="/Applications"
TMP_DIR=$(mktemp -d)

# Cleanup temp dir on exit (success or failure)
trap 'rm -rf "$TMP_DIR"' EXIT

# ── 0. Pre-install checks ───────────────────────────────────────────────────
echo "▶  Ensuring app is stopped…"
pkill -x "Easy Time Zones" || true

echo ""
echo "🕐  Easy Time Zones – Installer"
echo "────────────────────────────────"

# ── 1. Find latest release info ───────────────────────────────────────────────
echo "▶  Fetching latest release info from GitHub…"
RELEASE_JSON=$(curl -fsSL --max-time 15 \
  -H "Accept: application/vnd.github+json" \
  -H "Cache-Control: no-cache" \
  -H "User-Agent: EasyTimeZones-Installer" \
  "https://api.github.com/repos/${REPO}/releases/latest")
VERSION=$(printf '%s' "$RELEASE_JSON" | /usr/bin/python3 -c 'import json, sys; print(json.load(sys.stdin)["tag_name"])')
DOWNLOAD_URL=$(printf '%s' "$RELEASE_JSON" | /usr/bin/python3 -c 'import json, sys; assets = json.load(sys.stdin)["assets"]; dmg = next((a for a in assets if a["name"].endswith(".dmg")), None); print(dmg["browser_download_url"] if dmg else "")')
EXPECTED_SHA=$(printf '%s' "$RELEASE_JSON" | /usr/bin/python3 -c 'import json, sys; assets = json.load(sys.stdin)["assets"]; dmg = next((a for a in assets if a["name"].endswith(".dmg")), None); digest = dmg.get("digest", "") if dmg else ""; print(digest.split("sha256:", 1)[1] if digest.startswith("sha256:") else "")')

if [ -z "$DOWNLOAD_URL" ]; then
  echo "❌  Could not find a .dmg asset in the latest release (${VERSION:-unknown})."
  echo "    Please download manually from: https://github.com/${REPO}/releases/latest"
  exit 1
fi

echo "    Latest version: ${VERSION}"

# ── 2. Download ────────────────────────────────────────────────────────────────
DMG_PATH="${TMP_DIR}/EasyTimeZones.dmg"
echo "▶  Downloading ${VERSION}…"
curl -L --progress-bar --max-time 120 \
  -H "Accept: application/octet-stream" \
  -o "$DMG_PATH" \
  "$DOWNLOAD_URL"

# ── 3. Verify integrity (SHA-256 digest) ─────────────────────────────────────
if [ -n "$EXPECTED_SHA" ]; then
  echo "▶  Verifying checksum…"
  ACTUAL_SHA=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')
  if [ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]; then
    echo "❌  Checksum mismatch! The download may be corrupted or tampered with."
    echo "    Expected: ${EXPECTED_SHA}"
    echo "    Got:      ${ACTUAL_SHA}"
    exit 1
  fi
  echo "✅  Checksum verified."
else
  echo "⚠️   No SHA-256 digest found in the GitHub release metadata — skipping integrity check."
fi

# ── 4. Mount & Install ───────────────────────────────────────────────────────
echo "▶  Mounting DMG…"
# Mount without browsing, and grab the mount point
DEV_NAME=$(hdiutil attach -nobrowse -readonly "$DMG_PATH" | grep -o "/dev/disk[0-9]*" | head -1)
MOUNT_POINT="/Volumes/${APP_NAME}"

# Wait a second for mounting to stabilize
sleep 1

if [ ! -d "$MOUNT_POINT" ]; then
  # Try to find any new mount point if the name mismatch
  MOUNT_POINT=$(hdiutil info | grep "$DEV_NAME" | grep -o "/Volumes/.*" | head -1)
fi

if [ -z "$MOUNT_POINT" ] || [ ! -d "$MOUNT_POINT" ]; then
  echo "❌  Failed to mount DMG."
  exit 1
fi

echo "▶  Installing to ${INSTALL_DIR}…"
SOURCE_APP="${MOUNT_POINT}/${APP_NAME}.app"
if [ ! -d "$SOURCE_APP" ]; then
  echo "❌  Mounted DMG does not contain ${APP_NAME}.app."
  exit 1
fi

STAGED_APP="${TMP_DIR}/${APP_NAME}.app"
ditto "$SOURCE_APP" "$STAGED_APP"

if [ -d "${INSTALL_DIR}/${APP_NAME}.app" ]; then
  echo "    Removing existing installation…"
  rm -rf "${INSTALL_DIR}/${APP_NAME}.app"
fi

ditto "$STAGED_APP" "${INSTALL_DIR}/${APP_NAME}.app"

echo "▶  Cleaning up…"
hdiutil detach "$MOUNT_POINT" -quiet || hdiutil detach "$DEV_NAME" -quiet

echo ""
echo "✅  ${APP_NAME} ${VERSION} installed successfully."
echo ""
echo "   ⚠️  IMPORTANT: This app is NOT notarized by Apple."
echo "   To open it for the first time:"
echo "   1. Open your Applications folder."
echo "   2. Right-click (or Control-click) on 'Easy Time Zones'."
echo "   3. Select 'Open' from the menu."
echo "   4. Click 'Open' again in the security dialog."
echo ""
