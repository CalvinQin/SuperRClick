#!/bin/bash
# Uses a prebuilt Shared.framework and compiles the current production executor directly.
# Does not build/launch the app, use the clipboard, or change the user's preferences.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
framework_dir="${1:-$repo_root/build/review/Build/Products/Debug}"
framework_dir="$(cd "$framework_dir" && pwd)"
fixture_root="$(mktemp -d /tmp/superrclick-functional-core-XXXXXX)"
report_dir="${2:-$repo_root/output/review/functional-core}"
mkdir -p "$report_dir"
printf '%s\n' "$fixture_root" | tee "$report_dir/latest-fixtures.txt"
git -C "$repo_root" rev-parse HEAD > "$fixture_root/source-revision.txt"
/usr/bin/swiftc -swift-version 6 -parse-as-library \
    -module-cache-path "$fixture_root/module-cache" \
    -F "$framework_dir" -framework Shared \
    -Xlinker -rpath -Xlinker "$framework_dir" \
    "$repo_root/App/Bootstrap/PlatformActionExecutor.swift" \
    "$repo_root/Tests/Functional/CoreFileActionChecks.swift" \
    -o "$fixture_root/core-file-checks" > "$fixture_root/compile.log" 2>&1
shasum -a 256 "$repo_root/App/Bootstrap/PlatformActionExecutor.swift" \
    "$repo_root/Tests/Functional/CoreFileActionChecks.swift" \
    "$repo_root/Shared/Support/ExclusiveFileOutput.swift" \
    "$repo_root/Shared/Actions/NewFileData.swift" \
    "$repo_root/Shared/Actions/ZipArchivePlan.swift" "$framework_dir/Shared.framework/Shared" \
    > "$fixture_root/source-hashes.txt"
if [[ "${3:-}" == "--compile-only" ]]; then
    printf 'Compiled harness: %s/core-file-checks\n' "$fixture_root"
    exit 0
fi
"$fixture_root/core-file-checks" "$fixture_root" 2>&1 | tee "$fixture_root/execution.log"
set +e
python3 "$repo_root/Tests/Functional/verify_core_artifacts.py" "$fixture_root" 2>&1 | tee "$fixture_root/artifact-verification.log"
validation_status=${PIPESTATUS[0]}
set -e
cp "$fixture_root/results.json" "$fixture_root/matrix.md" "$fixture_root/execution.log" \
   "$fixture_root/artifact-verification.log" "$fixture_root/compile.log" "$fixture_root/source-revision.txt" \
   "$fixture_root/source-hashes.txt" "$report_dir/"
printf 'Review matrix: %s/matrix.md\n' "$report_dir"
exit "$validation_status"
