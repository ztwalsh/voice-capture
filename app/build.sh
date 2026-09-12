#!/bin/bash
# Produces a runnable, ad-hoc-signed Harps.app — PLAN.md Phase 5's build
# script. Regenerates the Xcode project first so a stale .xcodeproj can
# never silently ship an old source list.
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "xcodegen not found. Install it with: brew install xcodegen" >&2
    exit 1
fi

xcodegen generate

BUILD_DIR="$(pwd)/build"
xcodebuild -project Harps.xcodeproj -scheme Harps -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    CONFIGURATION_BUILD_DIR="$BUILD_DIR" \
    build

APP_PATH="$BUILD_DIR/Harps.app"
echo ""
echo "Built: $APP_PATH"
echo ""
echo "Next steps:"
echo "  1. Move Harps.app to /Applications — SMAppService's launch-at-login"
echo "     setting needs the app there to register reliably."
echo "  2. Launch it once, quit it, then grant Accessibility, Microphone, and"
echo "     Speech Recognition in System Settings › Privacy & Security."
echo "     (Accessibility is tied to the app's signature — see README.md's"
echo "     note on that if the hotkey stops responding after a rebuild.)"
