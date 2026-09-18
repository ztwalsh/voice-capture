#!/bin/bash
# Builds, signs, notarizes, and packages a Developer ID release of Harps for
# direct distribution (outside the Mac App Store — see Harps.entitlements
# for why: the App Sandbox and the global-hotkey/synthesized-paste flow this
# app is built around don't coexist).
#
# One-time setup before this script works, both requiring your own Apple ID
# (nothing here can do these for you):
#   1. Create a "Developer ID Application" certificate — Xcode → Settings →
#      Accounts → your Apple ID → Manage Certificates → "+".
#   2. Store notarization credentials once:
#        xcrun notarytool store-credentials harps-notary \
#          --apple-id <your-apple-id> --team-id HSZZQ94DM7 \
#          --password <an app-specific password from appleid.apple.com>
#
# Usage: scripts/release.sh
# Produces: build/Harps.app (signed + notarized), build/Harps.dmg (signed +
# notarized, volume name "Harps <version>" pulled from Info.plist's
# CFBundleShortVersionString/project.yml's MARKETING_VERSION), ready to hand
# out or upload to the website. The filename itself stays "Harps.dmg" on
# purpose — the website links to that stable path — the version only shows
# up in the mounted volume's name and the changelog entry the
# ship-harps-release skill adds alongside it.

set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Harps"
SCHEME="Harps"
TEAM_ID="HSZZQ94DM7"
SIGNING_IDENTITY="Developer ID Application: Zach Walsh ($TEAM_ID)"
NOTARY_PROFILE="harps-notary"
BUILD_DIR="build"
DERIVED_DATA="$BUILD_DIR/DerivedData"

echo "== Regenerating Xcode project =="
xcodegen generate

echo "== Building Release ($APP_NAME) =="
rm -rf "$DERIVED_DATA"
xcodebuild \
  -project "$APP_NAME.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  clean build

APP_PATH="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"
if [ ! -d "$APP_PATH" ]; then
  echo "error: expected app not found at $APP_PATH" >&2
  exit 1
fi

# Read straight back out of the built Info.plist rather than re-parsing
# project.yml — this is the value Xcode actually baked into the app, so it
# can't drift from what MARKETING_VERSION in project.yml says.
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
echo "== Version: $VERSION =="

# A plain `xcodebuild build` (not an archive+export) signs with
# `--timestamp=none` — confirmed live via `codesign -dvvv` (no "Timestamp="
# line, just the local "Signed Time"). Notarization rejects that outright
# ("signature does not include a secure timestamp"), so this re-signs with
# a real one before anything gets zipped up. No nested frameworks/dylibs
# here to worry about signing in order first — `Contents/Frameworks`
# doesn't even exist in this bundle — so a single top-level re-sign covers
# the whole app.
echo "== Re-signing with a secure timestamp for notarization =="
# Apple's timestamp-authority server is intermittently flaky — codesign
# fails outright rather than falling back, roughly 1 in 4 runs, confirmed
# repeatedly over many manual releases this session. Retrying the same
# command is the actual fix every time it's happened; there's nothing to
# diagnose beyond that.
for attempt in 1 2 3 4 5; do
  codesign --force --options runtime --entitlements Harps/Harps.entitlements \
    --sign "$SIGNING_IDENTITY" --timestamp "$APP_PATH" && \
    codesign -dvvv "$APP_PATH" 2>&1 | grep -q "^Timestamp=" && break
  echo "  (timestamp server hiccup, retrying: attempt $attempt)"
  sleep 5
done

echo "== Verifying code signature =="
codesign --verify --strict --verbose=2 "$APP_PATH"
codesign -dvvv "$APP_PATH" 2>&1 | grep -q "^Timestamp=" || {
  echo "error: re-signed app still has no secure timestamp after 5 attempts" >&2
  exit 1
}

echo "== Zipping for notarization =="
mkdir -p "$BUILD_DIR"
ZIP_PATH="$BUILD_DIR/$APP_NAME.zip"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "== Submitting to Apple notary service (this can take a few minutes) =="
xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

echo "== Stapling notarization ticket to the app =="
xcrun stapler staple "$APP_PATH"

STAGED_APP="$BUILD_DIR/$APP_NAME.app"
rm -rf "$STAGED_APP"
cp -R "$APP_PATH" "$STAGED_APP"

echo "== Building DMG =="
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"
rm -f "$DMG_PATH"
DMG_STAGING=$(mktemp -d)
trap 'rm -rf "$DMG_STAGING"' EXIT
cp -R "$STAGED_APP" "$DMG_STAGING/"

# The real drag-to-Applications layout (background image, arrow, fixed icon
# positions) — a plain `hdiutil create` just gives a bare Finder window with
# the app sitting there, confirmed by a fresh install on a second machine
# looking like a generic file folder. `create-dmg` drives the AppleScript
# that sets the window's icon layout/background; it's known to sometimes
# exit non-zero even when the DMG came out fine (a Finder-scripting quirk,
# not a real failure), so this checks for the actual output file rather
# than trusting its exit code.
create-dmg \
  --volname "$APP_NAME $VERSION" \
  --background "assets/dmg-background.png" \
  --window-size 660 420 \
  --window-pos 200 120 \
  --icon-size 128 \
  --icon "$APP_NAME.app" 165 190 \
  --app-drop-link 495 190 \
  --hide-extension "$APP_NAME.app" \
  --no-internet-enable \
  "$DMG_PATH" \
  "$DMG_STAGING" || true

if [ ! -f "$DMG_PATH" ]; then
  echo "error: create-dmg did not produce $DMG_PATH" >&2
  exit 1
fi

echo "== Signing DMG =="
for attempt in 1 2 3 4 5; do
  codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$DMG_PATH" && \
    codesign -dvvv "$DMG_PATH" 2>&1 | grep -q "^Timestamp=" && break
  echo "  (timestamp server hiccup, retrying: attempt $attempt)"
  sleep 5
done

echo "== Notarizing DMG =="
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

echo "== Stapling notarization ticket to the DMG =="
xcrun stapler staple "$DMG_PATH"

echo
echo "Done. Version $VERSION."
echo "  App: $STAGED_APP"
echo "  DMG: $DMG_PATH"
echo
echo "Sanity check before shipping:"
echo "  spctl -a -vv --type execute \"$STAGED_APP\""
echo "  spctl -a -vv --type open --context context:primary-signature \"$DMG_PATH\""
echo
echo "This script only builds the DMG. To ship it (copy to the website,"
echo "add a changelog.json entry, commit + push both repos), use the"
echo "ship-harps-release skill."
