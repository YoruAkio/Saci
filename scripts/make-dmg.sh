#!/bin/bash

# @note build a drag-to-install DMG for Saci
# @usage ./scripts/make-dmg.sh            (uses current version from project)
# @usage ./scripts/make-dmg.sh <version>  (override version label)
#
# @note requires an exported Saci.app and the create-dmg tool (brew install create-dmg)

set -e

PROJECT_FILE="Saci.xcodeproj/project.pbxproj"
APP_PATH="build/Saci.app"
STAGING_DIR="build/dmg-staging"

# @note resolve version
if [[ -n "$1" ]]; then
    VERSION="$1"
else
    VERSION=$(grep -m1 'MARKETING_VERSION' "$PROJECT_FILE" | sed 's/.*= \(.*\);/\1/' | tr -d ' ')
fi

DMG_NAME="Saci-${VERSION}.dmg"

# @note ensure the app exists
if [[ ! -d "$APP_PATH" ]]; then
    echo "Error: $APP_PATH not found. Build it first, e.g.:"
    echo "  xcodebuild -project Saci.xcodeproj -scheme Saci -configuration Release build CONFIGURATION_BUILD_DIR=./build"
    exit 1
fi

# @note ensure create-dmg is installed
if ! command -v create-dmg >/dev/null 2>&1; then
    echo "create-dmg not found. Install with: brew install create-dmg"
    exit 1
fi

# @note stage a clean folder containing only the app
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"

# @note remove any previous dmg
rm -f "$DMG_NAME"

echo "Building $DMG_NAME ..."
create-dmg \
    --volname "Saci" \
    --window-pos 200 120 \
    --window-size 540 380 \
    --icon-size 120 \
    --icon "Saci.app" 150 190 \
    --app-drop-link 390 190 \
    --hide-extension "Saci.app" \
    --no-internet-enable \
    "$DMG_NAME" \
    "$STAGING_DIR" \
|| create-dmg --volname "Saci" "$DMG_NAME" "$STAGING_DIR"

rm -rf "$STAGING_DIR"
echo "✓ Created $DMG_NAME"
