#!/usr/bin/env bash
set -euo pipefail

# Keep the legacy entry point on the verified universal packaging pipeline.
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/build_release_dmg.sh" "$@"
