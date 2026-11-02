#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! xcodebuild -version >/dev/null 2>&1; then
  echo "Full Xcode is required. Select it in Xcode > Settings > Locations > Command Line Tools." >&2
  exit 1
fi
mkdir -p build
xcodebuild -project BetterTube.xcodeproj -scheme BetterTube -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' build
APP='build/DerivedData/Build/Products/Release-iphoneos/BetterTube.app'
test -f "$APP/BetterTube"
# Only disposable build output is replaced.
rm -rf build/ipa-stage
mkdir -p build/ipa-stage/Payload
ditto "$APP" build/ipa-stage/Payload/BetterTube.app
rm -f build/BetterTube-unsigned.ipa
(cd build/ipa-stage && /usr/bin/zip -qr9 ../BetterTube-unsigned.ipa Payload)
/usr/bin/shasum -a 256 build/BetterTube-unsigned.ipa > build/BetterTube-unsigned.ipa.sha256
printf '%s\n' 'Created build/BetterTube-unsigned.ipa. Sign it with your sideloading tool before installing.'
