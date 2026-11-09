#!/bin/bash
# Notarize Toolbox with notarytool and staple the ticket.
# The keychain profile must be created once by the owner:
#   xcrun notarytool store-credentials toolbox-notary \
#     --apple-id <APPLE_ID> --team-id <TEAM_ID> --password <APP_PASSWORD>
# Without a profile / Developer ID cert, leave F8 as "ad-hoc + unsigned DMG".
set -euo pipefail

PROFILE="${NOTARY_PROFILE:-toolbox-notary}"
TARGETS=("$@")
if [ ${#TARGETS[@]} -eq 0 ]; then
  TARGETS=(dist/Toolbox.app dist/Toolbox.dmg)
fi

for target in "${TARGETS[@]}"; do
  if [ ! -e "$target" ]; then
    echo "notarize: skipping missing $target"
    continue
  fi
  echo "Submitting $target ..."
  xcrun notarytool submit "$target" --keychain-profile "$PROFILE" --wait
  xcrun stapler staple "$target"
done
echo "Done."
