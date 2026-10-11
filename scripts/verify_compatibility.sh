#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 /path/to/SuperRClick.app [expected-minimum-macos-version]" >&2
    echo "Checks bundle metadata and every Mach-O architecture; default minimum: 15.0." >&2
}

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    usage
    exit 2
fi

APP_PATH="${1%/}"
EXPECTED_MINIMUM="${2:-15.0}"
FAILURES=0

if [[ ! "$EXPECTED_MINIMUM" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
    echo "Invalid expected macOS version: $EXPECTED_MINIMUM" >&2
    exit 2
fi

if [ ! -d "$APP_PATH" ]; then
    echo "App bundle not found: $APP_PATH" >&2
    exit 1
fi

# Treat 15, 15.0, and 15.0.0 as the same version, without float comparisons.
matches_minimum() {
    local actual="$1"
    [[ "$actual" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]] || return 1
    awk -v actual="$actual" -v expected="$EXPECTED_MINIMUM" 'BEGIN {
        split(actual, a, "."); split(expected, e, ".");
        for (i = 1; i <= 3; i++) if ((a[i] + 0) != (e[i] + 0)) exit 1;
    }'
}

check_minimum() {
    local label="$1"
    local actual="$2"
    if matches_minimum "$actual"; then
        printf 'PASS %s: macOS %s\n' "$label" "$actual"
    else
        printf 'FAIL %s: expected macOS %s, found %s\n' "$label" "$EXPECTED_MINIMUM" "${actual:-missing}" >&2
        FAILURES=$((FAILURES + 1))
    fi
}

check_bundle() {
    local label="$1"
    local plist="$2"
    local executable_directory="$3"
    local minimum executable binary architectures architecture build_info binary_minimum

    if [ ! -f "$plist" ]; then
        echo "FAIL $label: missing Info.plist at $plist" >&2
        FAILURES=$((FAILURES + 1))
        return
    fi

    minimum="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$plist" 2>/dev/null || true)"
    check_minimum "$label Info.plist" "$minimum"

    executable="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$plist" 2>/dev/null || true)"
    binary="$executable_directory/$executable"
    if [ -z "$executable" ] || [ ! -f "$binary" ]; then
        echo "FAIL $label: missing bundle executable at $binary" >&2
        FAILURES=$((FAILURES + 1))
        return
    fi

    if ! architectures="$(xcrun lipo -archs "$binary")" || [ -z "$architectures" ]; then
        echo "FAIL $label: cannot read executable architectures" >&2
        FAILURES=$((FAILURES + 1))
        return
    fi

    for architecture in $architectures; do
        if ! build_info="$(xcrun vtool -arch "$architecture" -show-build "$binary")"; then
            echo "FAIL $label ($architecture): cannot read Mach-O build version" >&2
            FAILURES=$((FAILURES + 1))
            continue
        fi
        binary_minimum="$(awk '
            $1 == "platform" { is_macos = ($2 == "MACOS" || $2 == "1") }
            $1 == "minos" && is_macos { print $2; exit }
            $1 == "cmd" && $2 == "LC_VERSION_MIN_MACOSX" { legacy_macos = 1 }
            $1 == "version" && legacy_macos { print $2; exit }
        ' <<< "$build_info")"
        check_minimum "$label Mach-O ($architecture)" "$binary_minimum"
    done
}

check_bundle "App" \
    "$APP_PATH/Contents/Info.plist" \
    "$APP_PATH/Contents/MacOS"
check_bundle "Finder Sync extension" \
    "$APP_PATH/Contents/PlugIns/SuperRClickFinderSync.appex/Contents/Info.plist" \
    "$APP_PATH/Contents/PlugIns/SuperRClickFinderSync.appex/Contents/MacOS"
check_bundle "Shared framework" \
    "$APP_PATH/Contents/Frameworks/Shared.framework/Resources/Info.plist" \
    "$APP_PATH/Contents/Frameworks/Shared.framework"

if [ "$FAILURES" -gt 0 ]; then
    echo "Compatibility verification failed ($FAILURES checks). Rebuild all targets with the expected deployment target." >&2
    exit 1
fi

echo "Bundle minimum-version checks passed. This does not replace runtime testing on macOS $EXPECTED_MINIMUM."
