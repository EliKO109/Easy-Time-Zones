#!/usr/bin/env bash
# Easy Time Zones – Release Script
# Automates: Archive → Export → DMG → GitHub Release
#
# Usage:
#   ./release.sh [version]
#
# Examples:
#   ./release.sh            # Uses version from Xcode project
#   ./release.sh 1.2.0      # Forces a specific version tag
#
# Requirements:
#   - GitHub CLI (gh) installed and authenticated: brew install gh && gh auth login
#   - Xcode command line tools pointing to Xcode.app (not just CLT)
#     Run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}"
XCODEPROJ="${PROJECT_DIR}/Easy Time Zones.xcodeproj"
SCHEME="Easy Time Zones"
EXPORT_DIR="${SCRIPT_DIR}/.release_export"
DMG_OUTPUT_DIR="${SCRIPT_DIR}"
ARCHIVE_PATH="${EXPORT_DIR}/archive.xcarchive"

# ── 0. Sanity checks ──────────────────────────────────────────────────────────
if ! command -v gh &>/dev/null; then
  echo "❌  GitHub CLI (gh) not found. Install it with: brew install gh"
  exit 1
fi

if ! gh auth status &>/dev/null; then
  echo "❌  Not authenticated with GitHub CLI. Run: gh auth login"
  exit 1
fi

if ! xcodebuild -version &>/dev/null; then
  echo "❌  xcodebuild not available."
  echo "    Run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

# ── 1. Read version ───────────────────────────────────────────────────────────
if [ -n "$1" ]; then
  VERSION="$1"
else
  # Read from Xcode project
  VERSION=$(grep -m1 MARKETING_VERSION "${XCODEPROJ}/project.pbxproj" | sed 's/.*= //;s/;//')
fi

if [ -z "$VERSION" ]; then
  echo "❌  Could not determine version. Pass it as an argument: ./release.sh 1.2.0"
  exit 1
fi

  TAG="v${VERSION}"
fi

DMG_NAME="EasyTimeZones-${VERSION}.dmg"
APP_NAME="Easy Time Zones"

echo ""
echo "🚀  Easy Time Zones – Release Automation"
echo "──────────────────────────────────────────"
echo "    Version:  ${VERSION}"
echo "    Tag:      ${TAG}"

# ── 1.5. Bump Build Number ────────────────────────────────────────────────────
echo "▶  Incrementing Build Number (agvtool)…"
cd "${PROJECT_DIR}"
xcrun agvtool next-version -all &>/dev/null || echo "⚠️  Could not auto-increment build (check Xcode build settings)."
cd "${SCRIPT_DIR}"

CURRENT_BUILD=$(grep -m1 CURRENT_PROJECT_VERSION "${XCODEPROJ}/project.pbxproj" | sed 's/.*= //;s/;//')
echo "    Build:    ${CURRENT_BUILD:-N/A}"
echo ""

# ── 2. Archive ────────────────────────────────────────────────────────────────
echo "▶  Archiving with xcodebuild…"
rm -rf "$EXPORT_DIR"
mkdir -p "$EXPORT_DIR"

xcodebuild archive \
  -project "${XCODEPROJ}" \
  -scheme "${SCHEME}" \
  -configuration Release \
  -archivePath "${ARCHIVE_PATH}" \
  CODE_SIGN_STYLE=Automatic \
  | grep -E "(error:|warning:|Archive Succeeded|FAILED)"

echo "✅  Archive complete."

# ── 3. Export .app ────────────────────────────────────────────────────────────
echo "▶  Exporting .app…"
APP_PATH="${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app"

if [ ! -d "$APP_PATH" ]; then
  echo "❌  App not found in archive at: ${APP_PATH}"
  exit 1
fi

COPIED_APP="${EXPORT_DIR}/${APP_NAME}.app"
cp -R "$APP_PATH" "$COPIED_APP"
echo "✅  Exported: ${COPIED_APP}"

# ── 4. Package DMG ────────────────────────────────────────────────────────────
echo "▶  Creating DMG…"
TMP_DIR=$(mktemp -d)
STAGING="${TMP_DIR}/${APP_NAME}"
mkdir -p "$STAGING"
cp -R "$COPIED_APP" "$STAGING/"
ln -s /Applications "${STAGING}/Applications"

DMG_PATH="${DMG_OUTPUT_DIR}/${DMG_NAME}"
hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH" &>/dev/null

rm -rf "$TMP_DIR"
echo "✅  DMG created: ${DMG_PATH}"

# ── 4b. Generate SHA-256 checksum ─────────────────────────────────────────────
SHA_FILE="${DMG_PATH}.sha256"
shasum -a 256 "$DMG_PATH" > "$SHA_FILE"
DMG_SHA=$(awk '{print $1}' "$SHA_FILE")
echo "✅  Checksum: ${DMG_SHA}"

# ── 5. Git tag & push ─────────────────────────────────────────────────────────
echo "▶  Pushing git tag ${TAG}…"
cd "$SCRIPT_DIR"
git tag -a "${TAG}" -m "Release ${VERSION}" 2>/dev/null || {
  echo "ℹ️   Tag ${TAG} already exists, skipping tag creation."
}
git push origin "${TAG}" 2>/dev/null || echo "ℹ️   Tag already on remote."

# ── 6. Create GitHub Release & upload DMG + checksum ─────────────────────────
echo "▶  Creating GitHub Release ${TAG}…"
gh release create "${TAG}" "${DMG_PATH}" "${SHA_FILE}" \
  --title "Easy Time Zones ${VERSION}" \
  --notes "## What's New in ${VERSION}

- Bug fixes and improvements

---
**Install via Terminal:**
\`\`\`bash
curl -fsSL https://raw.githubusercontent.com/EliKO109/Easy-Time-Zones/main/install.sh | bash
\`\`\`

**SHA-256 Checksum** (for manual verification):
\`\`\`
${DMG_SHA}
\`\`\`

> ⚠️ This app is not notarized. Right-click → Open the first time to bypass macOS Gatekeeper.

Or download the DMG below." \
  --latest

# ── 7. Cleanup ────────────────────────────────────────────────────────────────
rm -rf "$EXPORT_DIR"

echo ""
echo "🎉  Release ${TAG} is live on GitHub!"
echo "    https://github.com/EliKO109/Easy-Time-Zones/releases/tag/${TAG}"
echo ""
