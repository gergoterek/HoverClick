#!/bin/zsh
set -euo pipefail

PROJECT_DIR="/Users/gergoterek/Movies/OBS/GPT/HoverClick"
APP_PATH="$PROJECT_DIR/HoverClick.app"
RESOURCES_DIR="$APP_PATH/Contents/Resources"
ICON_SOURCE="$PROJECT_DIR/Resources/HoverClick.icns"
SIGNING_IDENTITY="Apple Development: rizsutt@gmail.com (MVQ5PX4679)"

/usr/bin/make -C "$PROJECT_DIR" app

if [[ ! -f "$ICON_SOURCE" ]]; then
  echo "Missing app icon: $ICON_SOURCE"
  exit 1
fi

/bin/mkdir -p "$RESOURCES_DIR"
/bin/cp "$ICON_SOURCE" "$RESOURCES_DIR/HoverClick.icns"
/usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp=none "$APP_PATH"
