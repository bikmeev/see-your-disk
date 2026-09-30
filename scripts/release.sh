#!/bin/zsh
# Build, sign (Developer ID), notarize and package See Your Disk as a DMG, then publish a GitHub release.
#
# One-time setup (see docs/RELEASING.md):
#   1. A "Developer ID Application" certificate in your keychain
#   2. xcrun notarytool store-credentials "seeyourdisk-notary" --apple-id <id> --team-id X6C6J5GZ75 --password <app-specific-password>
#   3. gh auth login
#
# Usage: scripts/release.sh 1.0.0
set -euo pipefail

VERSION="${1:?usage: scripts/release.sh <version>}"
PROFILE="seeyourdisk-notary"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/export/SeeYourDisk.app"
DMG="$BUILD/SeeYourDisk-$VERSION.dmg"

rm -rf "$BUILD"; mkdir -p "$BUILD"
cd "$ROOT"

echo "▶ Archive"
xcodebuild -project SeeYourDisk.xcodeproj -scheme SeeYourDisk -configuration Release \
  -destination 'generic/platform=macOS' -archivePath "$BUILD/SeeYourDisk.xcarchive" \
  MARKETING_VERSION="$VERSION" ENABLE_HARDENED_RUNTIME=YES archive

echo "▶ Export (Developer ID)"
xcodebuild -exportArchive -archivePath "$BUILD/SeeYourDisk.xcarchive" \
  -exportOptionsPlist scripts/ExportOptions.plist -exportPath "$BUILD/export"

echo "▶ Verify signature"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "▶ Notarize app"
ditto -c -k --keepParent "$APP" "$BUILD/app.zip"
xcrun notarytool submit "$BUILD/app.zip" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$APP"

echo "▶ Make DMG"
STAGE="$BUILD/dmg"; mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"; ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "See Your Disk" -srcfolder "$STAGE" -ov -format UDZO "$DMG"

echo "▶ Notarize DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG"

echo "▶ Checksum"
( cd "$BUILD" && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256" )

echo "▶ GitHub release v$VERSION"
gh release create "v$VERSION" "$DMG" "$DMG.sha256" \
  --title "See Your Disk $VERSION" \
  --notes "Open-source edition (no purchases, Full Disk Access). Signed with Developer ID and notarized by Apple. The Mac App Store edition: https://apps.apple.com/us/app/clean-systemdata-seeyourdisk/id6817565741"

echo "✔ Done: $DMG"
