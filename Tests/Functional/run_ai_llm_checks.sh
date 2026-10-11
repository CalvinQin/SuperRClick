#!/bin/bash
# Compile current Shared sources; use synthetic keys and in-memory HTTP responses only.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
run_dir="$(mktemp -d /tmp/superrclick-ai-llm-XXXXXX)"
printf 'Artifacts: %s\n' "$run_dir"
common=(xcrun swiftc -swift-version 6 -DDEBUG -parse-as-library
        -target "$(uname -m)-apple-macos15.0" -module-cache-path "$run_dir/module-cache")
shared_sources=()
while IFS= read -r source; do shared_sources+=("$source"); done < <(rg --files "$repo_root/Shared" -g '*.swift' | sort)
"${common[@]}" -module-name Shared -emit-library -emit-module \
    -emit-module-path "$run_dir/Shared.swiftmodule" -o "$run_dir/libShared.dylib" \
    "${shared_sources[@]}" > "$run_dir/shared-build.log" 2>&1 || { cat "$run_dir/shared-build.log"; exit 1; }
"${common[@]}" -I "$run_dir" -L "$run_dir" -lShared \
    -Xlinker -rpath -Xlinker "$run_dir" \
    "$repo_root/Tests/Functional/AILLMChecks.swift" -o "$run_dir/ai-llm-checks" \
    > "$run_dir/checks-build.log" 2>&1 || { cat "$run_dir/checks-build.log"; exit 1; }
SUPERRCLICK_LLM_REPORT="$run_dir/results.json" "$run_dir/ai-llm-checks" 2>&1 | tee "$run_dir/execution.log"
