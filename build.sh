#!/bin/bash
# Build NeTool.app without Xcode — uses swiftc only.
# Prerequisites: Xcode Command Line Tools (xcode-select --install)

set -e

APP_NAME="NeTool"
SRC_DIR="NeTool"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
BIN_DIR="$APP_BUNDLE/Contents/MacOS"
RES_DIR="$APP_BUNDLE/Contents/Resources"

echo "🔨 Building $APP_NAME..."

# 1. Clean & create bundle structure
rm -rf "$APP_BUNDLE"
mkdir -p "$BIN_DIR" "$RES_DIR"

# 2. Compile Swift sources
swiftc -o "$BIN_DIR/$APP_NAME" \
    "$SRC_DIR/main.swift" \
    "$SRC_DIR/AppDelegate.swift" \
    "$SRC_DIR/NetSpeedMonitor.swift" \
    "$SRC_DIR/StatusBarView.swift" \
    "$SRC_DIR/SpeedInfoView.swift"

# 3. Create Info.plist (resolved from Xcode variables)
cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.3">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>NeTool</string>
	<key>CFBundleIdentifier</key>
	<string>com.tao.NeTool</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>NeTool</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.3</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>10.14</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSHumanReadableCopyright</key>
	<string>Copyright © 2018 Liu, Tao (Toni). All rights reserved.</string>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>
PLIST

# 4. Make executable
chmod +x "$BIN_DIR/$APP_NAME"

echo "✅ Build complete: $APP_BUNDLE"
echo "   Run with: open $APP_BUNDLE"
