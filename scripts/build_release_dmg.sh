#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_FILE="$ROOT_DIR/SuperRClick.xcodeproj"
SCHEME="SuperRClick"
DERIVED_DATA_DIR="$ROOT_DIR/build/release/DerivedData"
OUTPUT_DIR="$ROOT_DIR/output/release"
STAGING_DIR="$OUTPUT_DIR/staging"
APP_PATH="$DERIVED_DATA_DIR/Build/Products/Release/SuperRClick.app"
APP_ENTITLEMENTS="$ROOT_DIR/Config/SuperRClick.entitlements"
FINDERSYNC_ENTITLEMENTS="$ROOT_DIR/Config/SuperRClickFinderSync.entitlements"

sign_release_bundle() {
    local app_bundle="$1"
    local framework_path="$app_bundle/Contents/Frameworks/Shared.framework"
    local finder_sync_path="$app_bundle/Contents/PlugIns/SuperRClickFinderSync.appex"

    if [ -d "$framework_path" ]; then
        codesign --force --sign - --timestamp=none "$framework_path"
    fi

    if [ -d "$finder_sync_path" ]; then
        codesign \
            --force \
            --sign - \
            --timestamp=none \
            --entitlements "$FINDERSYNC_ENTITLEMENTS" \
            "$finder_sync_path"
    fi

    codesign \
        --force \
        --sign - \
        --timestamp=none \
        --entitlements "$APP_ENTITLEMENTS" \
        "$app_bundle"

    codesign --verify --verbose=2 "$app_bundle"
    if [ -d "$finder_sync_path" ]; then
        codesign --verify --verbose=2 "$finder_sync_path"
    fi
}

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "xcodegen is required but was not found on PATH." >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "Generating Xcode project..."
(cd "$ROOT_DIR" && xcodegen generate)

echo "Building Release app..."
xcodebuild \
    -project "$PROJECT_FILE" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    CODE_SIGNING_ALLOWED=NO \
    build

if [ ! -d "$APP_PATH" ]; then
    echo "Expected app bundle not found at: $APP_PATH" >&2
    exit 1
fi

APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "0.1.0")"
DMG_NAME="SuperRClick-${APP_VERSION}.dmg"
DMG_PATH="$OUTPUT_DIR/$DMG_NAME"

echo "Staging app bundle..."
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
ditto "$APP_PATH" "$STAGING_DIR/SuperRClick.app"

echo "Signing staged app bundle for local Finder Sync registration..."
sign_release_bundle "$STAGING_DIR/SuperRClick.app"

ln -s /Applications "$STAGING_DIR/Applications"

cat > "$STAGING_DIR/INSTALL.txt" <<'EOF'
Super RClick

Install:
1. Open the DMG.
2. Drag SuperRClick.app into Applications.
3. Launch Super RClick once.
4. If Finder Sync does not appear immediately, enable it in System Settings -> Extensions -> Finder Extensions.
5. If the menu still does not show, quit and reopen Finder.

The app bundle inside the DMG already includes the Finder Sync extension.
EOF

echo "Creating DMG..."
rm -f "$DMG_PATH"
hdiutil create \
    -volname "Super RClick" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_PATH"

echo "Release DMG created at: $DMG_PATH"
