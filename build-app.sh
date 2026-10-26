#!/bin/bash
# Builds NoteBuddy.app (menu bar only, ad-hoc signed) next to this script.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/NoteBuddy"

APP=NoteBuddy.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/NoteBuddy"
cp Support/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

echo "Built $(pwd)/$APP"
