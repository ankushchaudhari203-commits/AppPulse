#!/bin/bash
set -e

PROJECT="AppPulse.xcodeproj"
SCHEME="AppPulse"
BUILD_DIR=".build/derived/Build/Products/Release"
ZIP_NAME="AppPulse_release.zip"
PACKAGE_DIR=".build/package"

echo "==> Cleaning previous package..."
rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"

echo "==> Building $SCHEME (Release, arm64)..."
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "platform=macOS,arch=arm64" \
  -derivedDataPath ".build/derived" \
  build \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  ONLY_ACTIVE_ARCH=YES

APP_PATH="$BUILD_DIR/AppPulse.app"

if [ ! -d "$APP_PATH" ]; then
  echo "ERROR: AppPulse.app not found at $APP_PATH"
  exit 1
fi

echo "==> Found: $APP_PATH"

echo "==> Copying app and install script to package folder..."
cp -R "$APP_PATH" "$PACKAGE_DIR/AppPulse.app"
cp install.sh "$PACKAGE_DIR/install.sh"
chmod +x "$PACKAGE_DIR/install.sh"

echo "==> Creating $ZIP_NAME..."
rm -f "$ZIP_NAME"
cd "$PACKAGE_DIR"
zip -r "../../$ZIP_NAME" AppPulse.app install.sh -x "*.DS_Store"
cd - > /dev/null

echo ""
echo "=============================="
echo "  Done! Created: $ZIP_NAME"
echo "=============================="
echo ""
echo "Share AppPulse_release.zip with your team."
echo "Recipients: unzip the file, then run install.sh"
