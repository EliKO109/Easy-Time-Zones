#!/usr/bin/env bash
# Easy Time Zones – one-liner installer
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/EliKO109/Easy-Time-Zones/main/install.sh | bash

set -e

APP_NAME="Easy Time Zones"
REPO="EliKO109/Easy-Time-Zones"
INSTALL_DIR="/Applications"
TMP_DIR=$(mktemp -d)

echo ""
echo "🕐  Easy Time Zones – Installer"
echo "────────────────────────────────"

# ── 1. Find latest release download URL ───────────────────────────────────────
echo "▶  Fetching latest release info from GitHub…"
RELEASE_JSON=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest")
DOWNLOAD_URL=$(echo "$RELEASE_JSON" | grep '"browser_download_url"' | grep '\.zip' | head -1 | cut -d'"' -f4)
VERSION=$(echo "$RELEASE_JSON" | grep '"tag_name"' | head -1 | cut -d'"' -f4)

if [ -z "$DOWNLOAD_URL" ]; then
  echo "❌  Could not find a .zip asset in the latest release."
  echo "    Please download manually from: https://github.com/${REPO}/releases/latest"
  exit 1
fi

echo "    Latest version: ${VERSION}"

# ── 2. Download ────────────────────────────────────────────────────────────────
ZIP_PATH="${TMP_DIR}/EasyTimeZones.zip"
echo "▶  Downloading ${VERSION}…"
curl -fsSL -o "$ZIP_PATH" "$DOWNLOAD_URL"

# ── 3. Extract ─────────────────────────────────────────────────────────────────
echo "▶  Extracting…"
unzip -q "$ZIP_PATH" -d "$TMP_DIR"

# ── 4. Move to Applications ───────────────────────────────────────────────────
echo "▶  Installing to ${INSTALL_DIR}…"
# Remove old version if present
if [ -d "${INSTALL_DIR}/${APP_NAME}.app" ]; then
  rm -rf "${INSTALL_DIR}/${APP_NAME}.app"
fi
mv "${TMP_DIR}/${APP_NAME}.app" "${INSTALL_DIR}/"

# ── 5. Clean up ────────────────────────────────────────────────────────────────
rm -rf "$TMP_DIR"

echo ""
echo "✅  ${APP_NAME} ${VERSION} installed."
echo ""
echo "   To open it:"
echo "   ▸ Right-click → Open the first time (macOS Gatekeeper)"
echo ""
