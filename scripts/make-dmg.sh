#!/bin/bash
# Build a distributable DMG from dist/Toolbox.app (ad-hoc signed in F0-F9).
set -euo pipefail

DIST="${DIST:-dist}"
APP="$DIST/Toolbox.app"
DMG="$DIST/Toolbox.dmg"

if [ ! -d "$APP" ]; then
  echo "make-dmg: $APP not found. Run 'make universal' first." >&2
  exit 1
fi

rm -f "$DMG"
hdiutil create -volname Toolbox -srcfolder "$DIST" -ov -format UDZO "$DMG"
echo "Created $DMG"
