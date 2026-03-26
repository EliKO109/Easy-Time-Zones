#!/usr/bin/env bash
# Easy Time Zones – one-liner installer
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/EliKO109/Easy-Time-Zones/main/install.sh | bash

set -euo pipefail

APP_NAME="Easy Time Zones"
REPO="EliKO109/Easy-Time-Zones"
INSTALL_DIR="/Applications"
TMP_DIR=$(mktemp -d)

# Cleanup temp dir on exit (success or failure)
trap 'rm -rf "$TMP_DIR"' EXIT

echo ""
echo "🕐  Easy Time Zones – Installer"
echo "────────────────────────────────"

# ── 1. Find latest release download URL ───────────────────────────────────────
echo "▶  Fetching latest release info from GitHub…"
RELEASE_JSON=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest")
DOWNLOAD_URL=$(echo "$RELEASE_JSON" | grep '"browser_download_url"' | grep '\.zip' | head -1 | cut -d'"' -f4)
VERSION=$(echo "$RELEASE_JSON" | grep '"tag_name"' | head -1 | cut -d'"' -f4)
CHECKSUM_URL=$(echo "$RELEASE_JSON" | grep '"browser_download_url"' | grep '\.sha256' | head -1 | cut -d'"' -f4)

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

# ── 3. Verify integrity (SHA-256 checksum) ─────────────────────────────────────
if [ -n "$CHECKSUM_URL" ]; then
  echo "▶  Verifying checksum…"
  EXPECTED_SHA=$(curl -fsSL "$CHECKSUM_URL" | awk '{print $1}')
  ACTUAL_SHA=$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')
  if [ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]; then
    echo "❌  Checksum mismatch! The download may be corrupted or tampered with."
    echo "    Expected: ${EXPECTED_SHA}"
    echo "    Got:      ${ACTUAL_SHA}"
    exit 1
  fi
  echo "✅  Checksum verified."
else
  echo "⚠️   No .sha256 file found in this release — skipping integrity check."
fi

# ── 4. Extract ─────────────────────────────────────────────────────────────────
echo "▶  Extracting…"
unzip -q "$ZIP_PATH" -d "$TMP_DIR"

# ── 5. Move to Applications ───────────────────────────────────────────────────
echo "▶  Installing to ${INSTALL_DIR}…"
# Remove old version if present
if [ -d "${INSTALL_DIR}/${APP_NAME}.app" ]; then
  rm -rf "${INSTALL_DIR}/${APP_NAME}.app"
fi
mv "${TMP_DIR}/${APP_NAME}.app" "${INSTALL_DIR}/"

echo ""
echo "✅  ${APP_NAME} ${VERSION} installed."
echo ""
echo "   ⚠️  This app is NOT notarized by Apple."
echo "   To open it for the first time:"
echo "   ▸ Right-click → Open (to bypass macOS Gatekeeper)"
echo ""
