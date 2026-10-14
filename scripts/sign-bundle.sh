#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /path/to/App.app-or-Saver.saver" >&2
  exit 2
fi
bundle="$1"
[[ -d "$bundle" ]] || { echo "Bundle not found: $bundle" >&2; exit 1; }

# An ad-hoc signature establishes code integrity, NOT developer identity.
# For Gatekeeper-friendly distribution use a real Developer ID cert and notarization.
identity="${MACAPP_SIGNING_IDENTITY:--}"
entitlements=()
if [[ -n "${MACAPP_ENTITLEMENTS:-}" ]]; then
  entitlements=(--entitlements "$MACAPP_ENTITLEMENTS")
fi
if [[ "$identity" == "-" ]]; then
  /usr/bin/codesign --force --sign - --timestamp=none "${entitlements[@]}" "$bundle"
  echo "AD-HOC SIGNATURE: $bundle; macOS Gatekeeper may still block downloads."
else
  /usr/bin/codesign --force --options runtime --timestamp --sign "$identity" "${entitlements[@]}" "$bundle"
  echo "Developer ID signature applied: $bundle"
fi
/usr/bin/codesign --verify --deep --strict --verbose=2 "$bundle"
echo "Signature integrity verified: $bundle"
