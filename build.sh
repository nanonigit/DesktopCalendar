#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="DesktopCalendar"
BUNDLE_DIR="$DIR/$APP_NAME.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "=== 1. Cleaning old build ==="
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

echo "=== 2. Compiling Swift files ==="
swiftc -O \
    -target arm64-apple-macos14.0 \
    -framework SwiftUI \
    -framework AppKit \
    -framework EventKit \
    -framework Combine \
    -framework ServiceManagement \
    "$DIR"/Sources/*.swift \
    -o "$MACOS_DIR/$APP_NAME"

echo "=== 3. Copying Info.plist & AppIcon ==="
cp "$DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
if [ -f "$DIR/AppIcon.icns" ]; then
    cp "$DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

echo "=== 4. Code Signing ==="
codesign --force --deep --sign - "$BUNDLE_DIR"

echo "=== 5. Deploying to /Applications ==="
rm -rf "/Applications/$APP_NAME.app"
cp -R "$BUNDLE_DIR" "/Applications/$APP_NAME.app"

echo "=== Build & Deploy Complete: /Applications/$APP_NAME.app ==="
