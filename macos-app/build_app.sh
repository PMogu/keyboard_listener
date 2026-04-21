#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/.build/release"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="Keyboard Listener"
EXECUTABLE_NAME="KeyboardListenerMac"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"

export HOME=/tmp
export SWIFTPM_CACHE_PATH=/tmp/swiftpm
export SWIFTPM_SECURITY_PATH=/tmp/swiftpm-security
export CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache

cd "$ROOT_DIR"
swift build -c release

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$ROOT_DIR/Support/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$BUILD_DIR/$EXECUTABLE_NAME" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"

codesign --force --deep --sign - "$APP_BUNDLE"

echo "Built app bundle:"
echo "$APP_BUNDLE"
