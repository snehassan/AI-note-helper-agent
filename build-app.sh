#!/bin/bash
# Builds NoteBuddy.app (menu bar only, ad-hoc signed) next to this script.
# Calls swiftc directly so the build doesn't depend on SwiftPM's manifest tooling.
set -euo pipefail
cd "$(dirname "$0")"

OUT=.build/app
mkdir -p "$OUT"
swiftc -O -parse-as-library \
    -target "$(uname -m)-apple-macos13.0" \
    Sources/NoteBuddy/*.swift \
    -o "$OUT/NoteBuddy"

APP=NoteBuddy.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$OUT/NoteBuddy" "$APP/Contents/MacOS/NoteBuddy"
cp Support/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

echo "Built $(pwd)/$APP"
