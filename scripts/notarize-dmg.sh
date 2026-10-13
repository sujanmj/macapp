#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /path/to/App.dmg" >&2
  exit 2
fi
dmg="$1"
profile="${MACAPP_NOTARY_PROFILE:-}"
if [[ -z "$profile" ]]; then
  echo "Skipping notarization; MACAPP_NOTARY_PROFILE is not configured."
  echo "An ad-hoc signed or unnotarized DMG may be blocked by Gatekeeper."
  exit 0
fi
if [[ "${MACAPP_SIGNING_IDENTITY:--}" == "-" ]]; then
  echo "Notarization requires MACAPP_SIGNING_IDENTITY set to a Developer ID Application certificate." >&2
  exit 1
fi
xcrun notarytool submit "$dmg" --keychain-profile "$profile" --wait
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"
