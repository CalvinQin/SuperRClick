#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_FILE="$ROOT_DIR/SuperRClick.xcodeproj"
SCHEME="SuperRClick"
DERIVED_DATA_DIR="$ROOT_DIR/build/release/DerivedData"
OUTPUT_DIR="$ROOT_DIR/output/release"
APP_PATH="$DERIVED_DATA_DIR/Build/Products/Release/SuperRClick.app"
APP_ENTITLEMENTS="$ROOT_DIR/Config/SuperRClick.entitlements"
FINDERSYNC_ENTITLEMENTS="$ROOT_DIR/Config/SuperRClickFinderSync.entitlements"

sign_release_bundle() {
    local app_bundle="$1"
    local framework_path="$app_bundle/Contents/Frameworks/Shared.framework"
    local finder_sync_path="$app_bundle/Contents/PlugIns/SuperRClickFinderSync.appex"

    if [ -d "$framework_path" ]; then
        codesign --force --sign - --timestamp=none --options runtime "$framework_path"
    else
        echo "Missing shared framework: $framework_path" >&2
        exit 1
    fi

    if [ -d "$finder_sync_path" ]; then
        codesign \
            --force \
            --sign - \
            --timestamp=none \
            --options runtime \
            --entitlements "$FINDERSYNC_ENTITLEMENTS" \
            "$finder_sync_path"
    else
        echo "Missing Finder Sync extension: $finder_sync_path" >&2
        exit 1
    fi

    codesign \
        --force \
        --sign - \
        --timestamp=none \
        --options runtime \
        --entitlements "$APP_ENTITLEMENTS" \
        "$app_bundle"

    codesign --verify --strict --deep --verbose=2 "$app_bundle"
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
    ARCHS='arm64 x86_64' \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGNING_ALLOWED=NO \
    build

if [ ! -d "$APP_PATH" ]; then
    echo "Expected app bundle not found at: $APP_PATH" >&2
    exit 1
fi

APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
RELEASE_VERSION="${RELEASE_VERSION:-$APP_VERSION}"
case "$RELEASE_VERSION" in
    "$APP_VERSION"|"$APP_VERSION"-beta.*|"$APP_VERSION"-rc.*) ;;
    *) echo "Release version does not match app version $APP_VERSION" >&2; exit 1 ;;
esac
DMG_NAME="SuperRClick-${RELEASE_VERSION}.dmg"
DMG_PATH="$OUTPUT_DIR/$DMG_NAME"

echo "Staging app bundle..."
STAGING_DIR="$(mktemp -d "$OUTPUT_DIR/staging-XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
ditto "$APP_PATH" "$STAGING_DIR/SuperRClick.app"

echo "Signing staged app bundle for local Finder Sync registration..."
sign_release_bundle "$STAGING_DIR/SuperRClick.app"

"$ROOT_DIR/scripts/verify_compatibility.sh" "$STAGING_DIR/SuperRClick.app" 15.0
for binary in \
    "$STAGING_DIR/SuperRClick.app/Contents/MacOS/SuperRClick" \
    "$STAGING_DIR/SuperRClick.app/Contents/PlugIns/SuperRClickFinderSync.appex/Contents/MacOS/SuperRClickFinderSync" \
    "$STAGING_DIR/SuperRClick.app/Contents/Frameworks/Shared.framework/Shared"; do
    architectures="$(xcrun lipo -archs "$binary")"
    case " $architectures " in *" arm64 "*) ;; *) echo "Missing arm64: $binary" >&2; exit 1 ;; esac
    case " $architectures " in *" x86_64 "*) ;; *) echo "Missing x86_64: $binary" >&2; exit 1 ;; esac
done
EXTENSION_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$STAGING_DIR/SuperRClick.app/Contents/PlugIns/SuperRClickFinderSync.appex/Contents/Info.plist")"
if [ "$APP_VERSION" != "$EXTENSION_VERSION" ]; then
    echo "App and Finder extension versions do not match." >&2
    exit 1
fi

ln -s /Applications "$STAGING_DIR/Applications"
cp "$ROOT_DIR/LICENSE" "$STAGING_DIR/LICENSE.txt"

cat > "$STAGING_DIR/INSTALL.txt" <<'EOF'
Super RClick

Install:
1. Open the DMG.
2. Drag SuperRClick.app into Applications.
3. Launch Super RClick once.
4. Follow the setup guide. Enable Super RClick in System Settings -> General -> Login Items & Extensions -> Finder.
5. Complete the guide's real-menu check in a writable folder inside your home folder.

Desktop background: keep the app running and use Option+right-click.
Accessibility and Input Monitoring are optional and only needed for the desktop feature.

This community preview is locally ad-hoc signed, not Developer ID signed or notarized.
Gatekeeper may block an Internet download. Do not disable macOS security globally.
If you trust the source, use macOS's per-app Open Anyway option in Privacy & Security.
The build targets macOS 15+ and contains Apple Silicon and Intel binaries.
Actual macOS 15 / Intel runtime validation is still pending.

中文：安装后打开“使用向导”，启用 Finder 扩展，并实际测试一次新建文件。
桌面空白处使用 Option + 右键，需要应用运行以及可选的辅助功能和输入监控权限。
本预览版未经过 Apple 公证；请勿关闭系统的全局安全保护。

The app bundle inside the DMG already includes the Finder Sync extension.
EOF

echo "Creating DMG..."
hdiutil create \
    -volname "Super RClick" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_PATH"

hdiutil verify "$DMG_PATH"
(cd "$OUTPUT_DIR" && shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256")

echo "Release DMG created at: $DMG_PATH"
