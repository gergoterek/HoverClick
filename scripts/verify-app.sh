#!/bin/zsh
set -euo pipefail

PROJECT_DIR="/Users/gergoterek/Movies/OBS/GPT/HoverClick"
APP_PATH="$PROJECT_DIR/HoverClick.app"
BINARY_PATH="$APP_PATH/Contents/MacOS/HoverClick"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
PROCESS_NAME="HoverClick"

echo "app path = $APP_PATH"
echo "binary path = $BINARY_PATH"

if [[ ! -d "$APP_PATH" ]]; then
  echo "app bundle exists = NO"
  exit 1
fi

bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$INFO_PLIST")
echo "Info.plist bundle id = $bundle_id"

echo "codesign identity:"
/usr/bin/codesign -dvvv "$APP_PATH" 2>&1 | /usr/bin/sed -n '/^Authority=/p'

echo "codesign -dv output:"
/usr/bin/codesign -dv "$APP_PATH" 2>&1

echo "codesign verification:"
if /usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_PATH"; then
  echo "codesign verification passes = YES"
else
  echo "codesign verification passes = NO"
  exit 1
fi

process_count=$((/usr/bin/pgrep -x "$PROCESS_NAME" || true) | /usr/bin/wc -l | /usr/bin/tr -d ' ')
echo "HoverClick process count = $process_count"
if [[ "$process_count" == "1" ]]; then
  echo "exactly one HoverClick process running = YES"
else
  echo "exactly one HoverClick process running = NO"
fi
