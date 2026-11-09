#!/bin/bash
# Build a universal (arm64 + x86_64) Release archive and export the .app.
# Ad-hoc signed by default; set TEAM_ID + SIGN_ID for Developer ID builds.
set -euo pipefail

SCHEME="${SCHEME:-Toolbox}"
ARCHIVE="${ARCHIVE:-build/Toolbox.xcarchive}"
DIST="${DIST:-dist}"
SIGN_ID="${SIGN_ID:--}"

xcodebuild archive \
  -scheme "$SCHEME" \
  -configuration Release \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY="$SIGN_ID" \
  -archivePath "$ARCHIVE"

APP_PATH="$ARCHIVE/Products/Applications/Toolbox.app"
mkdir -p "$DIST"
rm -rf "$DIST/Toolbox.app"
cp -R "$APP_PATH" "$DIST/Toolbox.app"
echo "Exported to $DIST/Toolbox.app"
./scripts/verify-universal.sh "$DIST/Toolbox.app/Contents/MacOS/Toolbox"
