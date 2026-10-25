#!/bin/zsh
set -euo pipefail

source "${0:A:h}/release-config.sh"
RESOURCES_DIR="$APP_PATH/Contents/Resources"
ICON_SOURCE="$PROJECT_DIR/Resources/HoverClick.icns"

/usr/bin/make -C "$PROJECT_DIR" SIGNING_IDENTITY="$SIGNING_IDENTITY" CODESIGN_OPTIONS="${CODESIGN_OPTIONS:-}" app

if [[ ! -f "$ICON_SOURCE" ]]; then
  echo "Missing app icon: $ICON_SOURCE"
  exit 1
fi

/bin/mkdir -p "$RESOURCES_DIR"
/bin/cp "$ICON_SOURCE" "$RESOURCES_DIR/HoverClick.icns"
/usr/bin/codesign --force --sign "$SIGNING_IDENTITY" ${=CODESIGN_OPTIONS:-} --timestamp=none "$APP_PATH"
