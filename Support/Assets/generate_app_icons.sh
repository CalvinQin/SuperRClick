#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEFAULT_SOURCE="$SCRIPT_DIR/icon-source/master-logo.png"
PYTHON_GENERATOR="$PROJECT_ROOT/Support/Build/generate_app_icons.py"

if [[ $# -eq 0 ]]; then
  python3 "$PYTHON_GENERATOR"
  exit 0
fi

SOURCE_IMAGE="$1"
if [[ ! -f "$SOURCE_IMAGE" ]]; then
  echo "Source image not found: $SOURCE_IMAGE" >&2
  exit 1
fi

generate_iconset() {
  local output_dir="$1"
  local prefix="$2"

  mkdir -p "$output_dir"

  local names=(
    "16"
    "32"
    "64"
    "128"
    "256"
    "512"
    "1024"
  )

  for size in "${names[@]}"; do
    local output_path="$output_dir/${prefix}-${size}.png"
    /usr/bin/sips -s format png -z "$size" "$size" "$SOURCE_IMAGE" --out "$output_path" >/dev/null
  done

  cat > "$output_dir/Contents.json" <<EOF
{
  "images" : [
    { "idiom" : "mac", "filename" : "${prefix}-16.png", "scale" : "1x", "size" : "16x16" },
    { "idiom" : "mac", "filename" : "${prefix}-32.png", "scale" : "2x", "size" : "16x16" },
    { "idiom" : "mac", "filename" : "${prefix}-32.png", "scale" : "1x", "size" : "32x32" },
    { "idiom" : "mac", "filename" : "${prefix}-64.png", "scale" : "2x", "size" : "32x32" },
    { "idiom" : "mac", "filename" : "${prefix}-128.png", "scale" : "1x", "size" : "128x128" },
    { "idiom" : "mac", "filename" : "${prefix}-256.png", "scale" : "2x", "size" : "128x128" },
    { "idiom" : "mac", "filename" : "${prefix}-256.png", "scale" : "1x", "size" : "256x256" },
    { "idiom" : "mac", "filename" : "${prefix}-512.png", "scale" : "2x", "size" : "256x256" },
    { "idiom" : "mac", "filename" : "${prefix}-512.png", "scale" : "1x", "size" : "512x512" },
    { "idiom" : "mac", "filename" : "${prefix}-1024.png", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF
}

generate_iconset "$PROJECT_ROOT/App/Assets.xcassets/AppIcon.appiconset" "SuperRClick-AppIcon"
generate_iconset "$PROJECT_ROOT/Extensions/FinderSync/Assets.xcassets/AppIcon.appiconset" "SuperRClick-FinderSync-AppIcon"

mkdir -p "$SCRIPT_DIR/icon-source"
cp "$SOURCE_IMAGE" "$DEFAULT_SOURCE"

echo "Icon sets generated successfully."
