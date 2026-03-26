#!/usr/bin/env bash
# Easy Time Zones – Release Script
# Automates: Archive -> Export -> DMG -> Sparkle signature -> GitHub Release -> appcast.xml
#
# Usage:
#   ./release.sh [version]
#
# Optional environment variables:
#   SPARKLE_BIN=/path/to/Sparkle/bin
#   RELEASE_NOTES_MARKDOWN="* Fixed X\n* Added Y"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}"
XCODEPROJ="${PROJECT_DIR}/Easy Time Zones.xcodeproj"
SCHEME="Easy Time Zones"
EXPORT_DIR="${SCRIPT_DIR}/.release_export"
ARCHIVE_PATH="${EXPORT_DIR}/archive.xcarchive"
APPCAST_PATH="${SCRIPT_DIR}/appcast.xml"
APP_NAME="Easy Time Zones"
REPO_SLUG="EliKO109/Easy-Time-Zones"
RELEASES_PAGE="https://github.com/${REPO_SLUG}/releases"
APPCAST_URL="https://raw.githubusercontent.com/${REPO_SLUG}/main/appcast.xml"
DOWNLOAD_BASE_URL="https://github.com/${REPO_SLUG}/releases/download"
MIN_SYSTEM_VERSION="14.0"

xml_escape() {
    local value="$1"
    value="${value//&/&amp;}"
    value="${value//</&lt;}"
    value="${value//>/&gt;}"
    printf '%s' "$value"
}

clean_build_setting_value() {
    printf '%s' "$1" | sed 's/[[:space:]]*\/\/.*$//' | xargs
}

restore_info_plist_placeholders() {
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString \$(MARKETING_VERSION)" "${PROJECT_DIR}/EasyTimeZones-Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion \$(CURRENT_PROJECT_VERSION)" "${PROJECT_DIR}/EasyTimeZones-Info.plist"
}

set_marketing_version() {
    local version="$1"
    perl -0pi -e "s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = ${version};/g" "${XCODEPROJ}/project.pbxproj"
}

find_sparkle_bin() {
    if [ -n "${SPARKLE_BIN:-}" ] && [ -d "${SPARKLE_BIN}" ]; then
        printf '%s\n' "${SPARKLE_BIN}"
        return 0
    fi

    local vendored_bin="${PROJECT_DIR}/Vendor/Sparkle/bin"
    if [ -d "${vendored_bin}" ]; then
        printf '%s\n' "${vendored_bin}"
        return 0
    fi

    return 1
}

extract_attribute_from_file() {
    local file_path="$1"
    local attribute_name="$2"
    sed -n "s/.*${attribute_name}=\"\\([^\"]*\\)\".*/\\1/p" "$file_path" | head -n 1
}

render_appcast() {
    local release_notes
    release_notes="$(xml_escape "${RELEASE_NOTES_MARKDOWN:-* Bug fixes and improvements}")"

    cat > "${APPCAST_PATH}" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0"
     xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"
     xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>Easy Time Zones Updates</title>
        <link>${RELEASES_PAGE}</link>
        <description>Appcast feed for Easy Time Zones.</description>
        <language>en</language>
        <item>
            <title>Version ${VERSION}</title>
            <link>${RELEASE_TAG_URL}</link>
            <sparkle:version>${CURRENT_BUILD}</sparkle:version>
            <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>${MIN_SYSTEM_VERSION}</sparkle:minimumSystemVersion>
            <sparkle:fullReleaseNotesLink>${RELEASES_PAGE}</sparkle:fullReleaseNotesLink>
            <pubDate>${PUB_DATE}</pubDate>
            <description sparkle:format="markdown"><![CDATA[
${release_notes}
            ]]></description>
            <enclosure
                url="${DOWNLOAD_URL}"
                sparkle:edSignature="${SPARKLE_ED_SIGNATURE}"
                length="${SPARKLE_LENGTH}"
                type="application/octet-stream" />
        </item>
    </channel>
</rss>
EOF
}

sign_archive_for_sparkle() {
    if [ -n "${GENERATE_APPCAST_BIN:-}" ] && [ -x "${GENERATE_APPCAST_BIN}" ]; then
        local temp_updates_dir generated_appcast
        temp_updates_dir="$(mktemp -d)"
        cp "${DMG_PATH}" "${temp_updates_dir}/"

        if "${GENERATE_APPCAST_BIN}" "${temp_updates_dir}" >/dev/null 2>&1; then
            generated_appcast="${temp_updates_dir}/appcast.xml"
            if [ -f "${generated_appcast}" ]; then
                SPARKLE_ED_SIGNATURE="$(extract_attribute_from_file "${generated_appcast}" "sparkle:edSignature")"
                SPARKLE_LENGTH="$(extract_attribute_from_file "${generated_appcast}" "length")"
            fi
        fi

        rm -rf "${temp_updates_dir}"
    fi

    if [ -z "${SPARKLE_ED_SIGNATURE:-}" ] || [ -z "${SPARKLE_LENGTH:-}" ]; then
        if [ -z "${SIGN_UPDATE_BIN:-}" ] || [ ! -x "${SIGN_UPDATE_BIN}" ]; then
            echo "❌  Could not find Sparkle's sign_update tool."
            echo "    Set SPARKLE_BIN or provide Vendor/Sparkle/bin in the repo."
            exit 1
        fi

        local sign_output
        sign_output="$("${SIGN_UPDATE_BIN}" "${DMG_PATH}")"
        SPARKLE_ED_SIGNATURE="$(printf '%s\n' "${sign_output}" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p' | head -n 1)"
        SPARKLE_LENGTH="$(printf '%s\n' "${sign_output}" | sed -n 's/.*length="\([^"]*\)".*/\1/p' | head -n 1)"
    fi

    if [ -z "${SPARKLE_ED_SIGNATURE:-}" ] || [ -z "${SPARKLE_LENGTH:-}" ]; then
        echo "❌  Failed to extract Sparkle signature metadata for ${DMG_NAME}."
        exit 1
    fi
}

release_install_command() {
    printf '%s' 'curl -fsSLO https://raw.githubusercontent.com/EliKO109/Easy-Time-Zones/main/install.sh && bash install.sh'
}

if ! command -v gh >/dev/null 2>&1; then
    echo "❌  GitHub CLI (gh) not found. Install it with: brew install gh"
    exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
    echo "❌  Not authenticated with GitHub CLI. Run: gh auth login"
    exit 1
fi

if ! xcodebuild -version >/dev/null 2>&1; then
    echo "❌  xcodebuild not available."
    echo "    Run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    exit 1
fi

SPARKLE_BIN_DIR="$(find_sparkle_bin || true)"
GENERATE_APPCAST_BIN=""
SIGN_UPDATE_BIN=""

if [ -n "${SPARKLE_BIN_DIR}" ]; then
    GENERATE_APPCAST_BIN="${SPARKLE_BIN_DIR}/generate_appcast"
    SIGN_UPDATE_BIN="${SPARKLE_BIN_DIR}/sign_update"
fi

if [ "${1:-}" != "" ]; then
    VERSION="$1"
    set_marketing_version "${VERSION}"
else
    VERSION="$(clean_build_setting_value "$(grep -m1 MARKETING_VERSION "${XCODEPROJ}/project.pbxproj" | sed 's/.*= //;s/;//')")"
fi

if [ -z "${VERSION}" ]; then
    echo "❌  Could not determine version. Pass it as an argument: ./release.sh 1.2.0"
    exit 1
fi

TAG="v${VERSION}"
DMG_NAME="EasyTimeZones-${VERSION}.dmg"
DMG_PATH="${SCRIPT_DIR}/${DMG_NAME}"
SHA_FILE="${DMG_PATH}.sha256"
DOWNLOAD_URL="${DOWNLOAD_BASE_URL}/${TAG}/${DMG_NAME}"
RELEASE_TAG_URL="https://github.com/${REPO_SLUG}/releases/tag/${TAG}"
PUB_DATE="$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')"

if git rev-parse "${TAG}" >/dev/null 2>&1 || git ls-remote --exit-code --tags origin "refs/tags/${TAG}" >/dev/null 2>&1; then
    echo "❌  Tag ${TAG} already exists. Choose a new version."
    exit 1
fi

if gh release view "${TAG}" >/dev/null 2>&1; then
    echo "❌  GitHub release ${TAG} already exists. Choose a new version."
    exit 1
fi

echo ""
echo "🚀  Easy Time Zones – Release Automation"
echo "──────────────────────────────────────────"
echo "    Version:  ${VERSION}"
echo "    Tag:      ${TAG}"
echo "    Feed:     ${APPCAST_URL}"

echo "▶  Incrementing Build Number (agvtool)…"
cd "${PROJECT_DIR}"
xcrun agvtool next-version -all >/dev/null 2>&1 || echo "⚠️  Could not auto-increment build (check Xcode build settings)."
restore_info_plist_placeholders
cd "${SCRIPT_DIR}"

CURRENT_BUILD="$(clean_build_setting_value "$(grep -m1 CURRENT_PROJECT_VERSION "${XCODEPROJ}/project.pbxproj" | sed 's/.*= //;s/;//')")"
echo "    Build:    ${CURRENT_BUILD:-N/A}"
echo ""

echo "▶  Archiving with xcodebuild…"
rm -rf "${EXPORT_DIR}"
mkdir -p "${EXPORT_DIR}"

xcodebuild archive \
    -project "${XCODEPROJ}" \
    -scheme "${SCHEME}" \
    -configuration Release \
    -archivePath "${ARCHIVE_PATH}" \
    CODE_SIGN_STYLE=Automatic \
    | grep -E "(error:|warning:|Archive Succeeded|FAILED)"

echo "✅  Archive complete."

echo "▶  Exporting .app…"
APP_PATH="${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app"

if [ ! -d "${APP_PATH}" ]; then
    echo "❌  App not found in archive at: ${APP_PATH}"
    exit 1
fi

COPIED_APP="${EXPORT_DIR}/${APP_NAME}.app"
cp -R "${APP_PATH}" "${COPIED_APP}"
echo "✅  Exported: ${COPIED_APP}"

echo "▶  Creating DMG…"
TMP_DIR="$(mktemp -d)"
STAGING="${TMP_DIR}/${APP_NAME}"
mkdir -p "${STAGING}"
cp -R "${COPIED_APP}" "${STAGING}/"
ln -s /Applications "${STAGING}/Applications"

hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${STAGING}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}" >/dev/null

rm -rf "${TMP_DIR}"
echo "✅  DMG created: ${DMG_PATH}"

shasum -a 256 "${DMG_PATH}" > "${SHA_FILE}"
DMG_SHA="$(awk '{print $1}' "${SHA_FILE}")"
echo "✅  Checksum: ${DMG_SHA}"

echo "▶  Signing archive for Sparkle…"
sign_archive_for_sparkle
echo "✅  Sparkle length: ${SPARKLE_LENGTH}"

echo "▶  Updating appcast.xml…"
render_appcast

echo "▶  Pushing git tag ${TAG}…"
git tag -a "${TAG}" -m "Release ${VERSION}"
git push origin "${TAG}"

echo "▶  Creating GitHub Release ${TAG}…"
gh release create "${TAG}" "${DMG_PATH}" "${SHA_FILE}" \
    --title "Easy Time Zones ${VERSION}" \
    --notes "## What's New in ${VERSION}

- Bug fixes and improvements

---
**Install via Terminal:**
\`\`\`bash
$(release_install_command)
\`\`\`

**SHA-256 Checksum** (for manual verification):
\`\`\`
${DMG_SHA}
\`\`\`

**Sparkle Ed25519 signature**:
\`\`\`
${SPARKLE_ED_SIGNATURE}
\`\`\`

> ⚠️ This app is not notarized. Right-click → Open the first time to bypass macOS Gatekeeper.

Or download the DMG below." \
    --latest

echo "▶  Committing release metadata…"
git add "${XCODEPROJ}/project.pbxproj" "${APPCAST_PATH}"
if ! git diff --cached --quiet; then
    git commit -m "chore: release ${VERSION}"
fi

echo "▶  Pushing branch updates…"
git push origin main

rm -rf "${EXPORT_DIR}"

echo ""
echo "🎉  Release ${TAG} is live on GitHub!"
echo "    ${RELEASE_TAG_URL}"
echo "    Appcast: ${APPCAST_URL}"
echo ""
