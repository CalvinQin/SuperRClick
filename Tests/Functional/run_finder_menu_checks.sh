#!/bin/bash
# Compiles the production Finder menu composer with a selector-only stub.
# No app/extension is launched; state is injected and fixtures are isolated.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
framework_dir="${1:-$repo_root/build/review/Build/Products/Debug}"
framework_dir="$(cd "$framework_dir" && pwd)"
fixture_root="$(mktemp -d /tmp/superrclick-finder-menu-XXXXXX)"
report_dir="${2:-$repo_root/output/review/functional-finder-menu}"
mkdir -p "$report_dir"
printf '%s\n' "$fixture_root" | tee "$report_dir/latest-fixtures.txt"
/usr/bin/swiftc -swift-version 6 -parse-as-library \
    -target "$(uname -m)-apple-macos15.0" \
    -module-cache-path "$fixture_root/module-cache" \
    -F "$framework_dir" -framework Shared \
    -Xlinker -rpath -Xlinker "$framework_dir" \
    "$repo_root/Extensions/FinderSync/SuperRClickFinderContext.swift" \
    "$repo_root/Extensions/FinderSync/SuperRClickFinderMenuComposer.swift" \
    "$repo_root/Tests/Functional/FinderMenuChecks.swift" \
    -o "$fixture_root/finder-menu-checks" > "$fixture_root/compile.log" 2>&1
set +e
"$fixture_root/finder-menu-checks" "$fixture_root" 2>&1 | tee "$fixture_root/execution.log"
validation_status=${PIPESTATUS[0]}
set -e
cp "$fixture_root/results.json" "$fixture_root/matrix.md" "$fixture_root/compile.log" \
    "$fixture_root/execution.log" "$report_dir/"
printf 'Review matrix: %s/matrix.md\n' "$report_dir"
exit "$validation_status"
