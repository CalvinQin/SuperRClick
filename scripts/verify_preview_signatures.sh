#!/usr/bin/env bash
# The community preview is ad-hoc signed, not Developer ID signed/notarized.
set -euo pipefail
APP="${1:?Usage: verify_preview_signatures.sh path/to/SuperRClick.app}"
codesign --verify --strict --deep --verbose=2 "$APP"
for bundle in \
    "$APP/Contents/Frameworks/Shared.framework" \
    "$APP/Contents/PlugIns/SuperRClickFinderSync.appex" \
    "$APP"; do
    details="$(codesign -d --verbose=4 "$bundle" 2>&1)"
    if ! grep -q 'Signature=adhoc' <<< "$details"; then
        echo "Expected ad-hoc preview signature: $bundle" >&2
        exit 1
    fi
    if grep -Eq 'flags=.*runtime' <<< "$details"; then
        echo "Ad-hoc preview must not enable runtime library validation: $bundle" >&2
        exit 1
    fi
done
