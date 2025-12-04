#!/bin/bash

# Build script for MemoryMonitor macOS app

set -e

echo "🔨 Building MemoryMonitor..."

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ Error: This script must be run on macOS"
    exit 1
fi

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Error: Xcode is not installed"
    echo "Please install Xcode from the App Store"
    exit 1
fi

# Build configuration (default: Release)
CONFIGURATION="${1:-Release}"

# Build the app
echo "Building with configuration: $CONFIGURATION"
xcodebuild \
    -project MemoryMonitor/MemoryMonitor.xcodeproj \
    -scheme MemoryMonitor \
    -configuration "$CONFIGURATION" \
    -derivedDataPath build \
    build

# Check if build succeeded
if [ $? -eq 0 ]; then
    echo "✅ Build succeeded!"
    echo ""
    echo "App location:"
    APP_PATH="build/Build/Products/$CONFIGURATION/MemoryMonitor.app"

    if [ -d "$APP_PATH" ]; then
        echo "  $APP_PATH"
        echo ""
        echo "To install, run:"
        echo "  cp -R \"$APP_PATH\" /Applications/"
        echo ""
        echo "To run directly:"
        echo "  open \"$APP_PATH\""
    else
        echo "⚠️  Warning: App bundle not found at expected location"
    fi
else
    echo "❌ Build failed"
    exit 1
fi
