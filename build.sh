#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

APP_NAME="MagicChord"
BUILD_DIR="$SCRIPT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "=== Building $APP_NAME for macOS ==="

# Check if Xcode is installed and available
if [ -d "/Applications/Xcode.app" ]; then
    echo "Building with Xcode ($APP_NAME.xcodeproj)..."
    DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
        -project "$APP_NAME.xcodeproj" \
        -scheme "$APP_NAME" \
        -configuration Release \
        -derivedDataPath "$BUILD_DIR/DerivedData" \
        -destination "platform=macOS" \
        build -quiet

    rm -rf "$APP_BUNDLE"
    cp -R "$BUILD_DIR/DerivedData/Build/Products/Release/$APP_NAME.app" "$APP_BUNDLE"
    codesign --force --deep --sign - "$APP_BUNDLE"
else
    echo "Xcode not found, compiling using swiftc..."
    CONTENTS_DIR="$APP_BUNDLE/Contents"
    MACOS_DIR="$CONTENTS_DIR/MacOS"
    RESOURCES_DIR="$CONTENTS_DIR/Resources"

    rm -rf "$BUILD_DIR"
    mkdir -p "$MACOS_DIR"
    mkdir -p "$RESOURCES_DIR"

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

    swiftc \
        -O \
        -import-objc-header "MultitouchBridge.h" \
        -F /System/Library/PrivateFrameworks \
        -framework MultitouchSupport \
        -framework Cocoa \
        -framework SwiftUI \
        -framework ApplicationServices \
        -framework ServiceManagement \
        "${SWIFT_FILES[@]}" \
        -o "$MACOS_DIR/$APP_NAME"

    cp Info.plist "$CONTENTS_DIR/Info.plist"
    if [ -f "AppIcon.icns" ]; then
        cp AppIcon.icns "$RESOURCES_DIR/AppIcon.icns"
    fi
    codesign --force --deep --sign - "$APP_BUNDLE"
fi

echo "=== Build Complete! ==="
echo "Application created at: $APP_BUNDLE"
