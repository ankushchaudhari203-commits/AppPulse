#!/bin/bash

APP_NAME="AppPulse.app"
DEST="/Applications/$APP_NAME"

echo "=============================="
echo "  AppPulse Installer"
echo "=============================="
echo ""

# Find the .app next to this script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_SRC="$SCRIPT_DIR/$APP_NAME"

if [ ! -d "$APP_SRC" ]; then
  echo "ERROR: $APP_NAME not found next to this script."
  echo "Make sure you unzipped the full package and run this from inside the folder."
  exit 1
fi

echo "==> Removing Gatekeeper quarantine flag..."
xattr -cr "$APP_SRC"

echo "==> Installing to /Applications..."
if [ -d "$DEST" ]; then
  echo "==> Removing previous version..."
  rm -rf "$DEST"
fi

cp -R "$APP_SRC" "$DEST"

echo ""
echo "=============================="
echo "  AppPulse installed!"
echo "  Open it from /Applications"
echo "=============================="
echo ""

# Offer to open it now
read -p "Open AppPulse now? [y/N] " choice
if [[ "$choice" =~ ^[Yy]$ ]]; then
  open "$DEST"
fi
