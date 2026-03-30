#!/bin/bash

# Exit on explicitly thrown error
set -e

APP_NAME="Super RClick"
PROJECT_DIR="$(pwd)"
BUILD_DIR="${PROJECT_DIR}/DerivedData/ReleaseBuild"
TEMP_DMG_DIR="${PROJECT_DIR}/temp_dmg"
OUTPUT_DMG="${PROJECT_DIR}/build/${APP_NAME}_v1.0.dmg"

echo "🧹 Cleaning previous builds..."
rm -rf "${BUILD_DIR}"
rm -rf "${TEMP_DMG_DIR}"
mkdir -p "${PROJECT_DIR}/build"

echo "🏗 Building ${APP_NAME} for Release..."
xcodebuild clean build \
  -scheme "SuperRClick" \
  -configuration Release \
  -destination "platform=macOS" \
  SYMROOT="${BUILD_DIR}" \
  -quiet

echo "📦 Preparing DMG folders..."
mkdir -p "${TEMP_DMG_DIR}"

# Copy the built .app to the DMG staging folder
cp -R "${BUILD_DIR}/Release/SuperRClick.app" "${TEMP_DMG_DIR}/${APP_NAME}.app"

# Add a symlink to /Applications
ln -s /Applications "${TEMP_DMG_DIR}/Applications"

echo "💽 Creating DMG..."
hdiutil create -volname "${APP_NAME}" -srcfolder "${TEMP_DMG_DIR}" -ov -format UDZO "${OUTPUT_DMG}"

echo "🧹 Cleaning up temp files..."
rm -rf "${TEMP_DMG_DIR}"
rm -rf "${BUILD_DIR}"

echo "✅ DMG generated successfully at: ${OUTPUT_DMG}"
