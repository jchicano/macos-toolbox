#!/bin/bash
# Verify that a Mach-O binary contains both x86_64 and arm64 slices.
set -euo pipefail

BIN="${1:-dist/Toolbox.app/Contents/MacOS/Toolbox}"
if [ ! -f "$BIN" ]; then
  echo "verify-universal: binary not found: $BIN" >&2
  exit 1
fi
ARCHS="$(lipo -archs "$BIN")"
echo "Architectures: $ARCHS"
if [ "$ARCHS" != "x86_64 arm64" ] && [ "$ARCHS" != "arm64 x86_64" ]; then
  echo "verify-universal: FAIL (expected x86_64 + arm64)" >&2
  exit 1
fi
echo "verify-universal: OK"
