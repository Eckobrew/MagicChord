#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

APP_NAME="MagicChord"
BUILD_DIR="$SCRIPT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "=== Building $APP_NAME for macOS ==="

# Clean build directory
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Source files
SWIFT_FILES=(
    "main.swift"
    "AppDelegate.swift"
    "MagicChordEngine.swift"
    "MultitouchDeviceManager.swift"
    "Preferences.swift"
    "TouchState.swift"
    "VisualizerView.swift"
    "SettingsWindowController.swift"
)

echo "Compiling Swift sources..."
swiftc \
    -O \
    -import-objc-header "MultitouchBridge.h" \
    -F /System/Library/PrivateFrameworks \
    -framework MultitouchSupport \
    -framework Cocoa \
    -framework SwiftUI \
    -framework ApplicationServices \
    "${SWIFT_FILES[@]}" \
    -o "$MACOS_DIR/$APP_NAME"

# Copy Info.plist
cp Info.plist "$CONTENTS_DIR/Info.plist"

# Copy AppIcon if available
if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns "$RESOURCES_DIR/AppIcon.icns"
fi

# Code signing (ad-hoc)
echo "Signing application bundle..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "=== Build Complete! ==="
echo "Application created at: $APP_BUNDLE"
