#!/usr/bin/env bash
set -euo pipefail

# Compatibility entry point for the authored Swift vector pipeline.
# No external source images or downloaded icon libraries are used.
if [[ $# -ne 0 ]]; then
  echo "Usage: bash Support/Assets/generate_app_icons.sh" >&2
  echo "Edit the original paths in scripts/render_original_icons.swift instead of importing a bitmap." >&2
  exit 2
fi

ICON_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ICON_PROJECT_ROOT="$(cd "$ICON_SCRIPT_DIR/../.." && pwd)"
ICON_BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/superrclick-icons.XXXXXX")"
trap 'rm -rf "$ICON_BUILD_DIR"' EXIT

xcrun swiftc -swift-version 6 -parse-as-library \
  -module-cache-path "$ICON_BUILD_DIR/module-cache" \
  "$ICON_PROJECT_ROOT/Shared/Design/RClickIcon.swift" \
  "$ICON_PROJECT_ROOT/scripts/render_original_icons.swift" \
  -o "$ICON_BUILD_DIR/render-original-icons"
"$ICON_BUILD_DIR/render-original-icons" "$ICON_PROJECT_ROOT"
