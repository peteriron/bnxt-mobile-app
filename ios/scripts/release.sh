#!/bin/bash
# Archive the app and upload it to App Store Connect with the API key (no Apple ID / 2FA).
# Called by `fastlane build_and_upload`. Needs ASC_KEY_ID and ASC_ISSUER_ID (ios/fastlane/.env) and the .p8 key.
set -euo pipefail
IOS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$IOS_DIR"
if [[ -f fastlane/.env ]]; then set -a; source fastlane/.env; set +a; fi
: "${ASC_KEY_ID:?Set ASC_KEY_ID}" "${ASC_ISSUER_ID:?Set ASC_ISSUER_ID}"
KEY_PATH="${ASC_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8}"
[[ -f "$KEY_PATH" ]] || { echo "Missing API key at $KEY_PATH" >&2; exit 1; }

BUILD_DIR="$IOS_DIR/../.tmp/build"
ARCHIVE="$BUILD_DIR/BNXT.xcarchive"
EXPORT="$BUILD_DIR/export"
AUTH=(-allowProvisioningUpdates -authenticationKeyPath "$KEY_PATH"
      -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")

xcodegen generate
rm -rf "$ARCHIVE" "$EXPORT"
xcodebuild -project BNXT.xcodeproj -scheme BNXT -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" "${AUTH[@]}" archive
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT" \
  -exportOptionsPlist ExportOptions.plist "${AUTH[@]}"
echo "Uploaded. Processing in App Store Connect takes a few minutes."
