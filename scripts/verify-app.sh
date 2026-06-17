#!/bin/zsh
set -euo pipefail

PROJECT_DIR="/Users/gergoterek/Movies/OBS/GPT/HoverClick"
APP_PATH="$PROJECT_DIR/HoverClick.app"
BINARY_PATH="$APP_PATH/Contents/MacOS/HoverClick"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
PROCESS_NAME="HoverClick"
SPARKLE_FRAMEWORK="$APP_PATH/Contents/Frameworks/Sparkle.framework"
SPARKLE_INFO_PLIST="$SPARKLE_FRAMEWORK/Versions/B/Resources/Info.plist"
EXPECTED_SPARKLE_VERSION="2.9.3"
EXPECTED_SPARKLE_FEED_URL="https://gergoterek.github.io/HoverClick/appcast.xml"
EXPECTED_SPARKLE_PUBLIC_KEY="093ZOOvjGmr8WkI31IzBnjGwM3GXZU1q/qgDgADWm9o="
EXPECTED_SIGNING_IDENTITY="Apple Development: rizsutt@gmail.com (MVQ5PX4679)"

echo "app path = $APP_PATH"
echo "binary path = $BINARY_PATH"

if [[ ! -d "$APP_PATH" ]]; then
  echo "app bundle exists = NO"
  exit 1
fi

bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$INFO_PLIST")
echo "Info.plist bundle id = $bundle_id"

icon_file=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" "$INFO_PLIST")
icon_path="$APP_PATH/Contents/Resources/$icon_file"
echo "Info.plist icon file = $icon_file"
if [[ "$icon_file" != "HoverClick.icns" ]]; then
  echo "expected app icon file = NO"
  exit 1
fi
if [[ -s "$icon_path" ]]; then
  echo "app icon resource exists = YES"
else
  echo "app icon resource exists = NO"
  exit 1
fi

echo "Sparkle framework path = $SPARKLE_FRAMEWORK"
if [[ ! -d "$SPARKLE_FRAMEWORK" ]]; then
  echo "Sparkle framework embedded = NO"
  exit 1
fi
if [[ ! -s "$SPARKLE_FRAMEWORK/Versions/B/Sparkle" ]]; then
  echo "Sparkle executable exists = NO"
  exit 1
fi
sparkle_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$SPARKLE_INFO_PLIST")
echo "Sparkle version = $sparkle_version"
if [[ "$sparkle_version" != "$EXPECTED_SPARKLE_VERSION" ]]; then
  echo "expected Sparkle version = NO"
  exit 1
fi
if /usr/bin/otool -L "$BINARY_PATH" | /usr/bin/grep -F "@rpath/Sparkle.framework" >/dev/null; then
  echo "binary links Sparkle via rpath = YES"
else
  echo "binary links Sparkle via rpath = NO"
  /usr/bin/otool -L "$BINARY_PATH"
  exit 1
fi

feed_url=$(/usr/libexec/PlistBuddy -c "Print :SUFeedURL" "$INFO_PLIST")
public_key=$(/usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" "$INFO_PLIST")
automatic_checks=$(/usr/libexec/PlistBuddy -c "Print :SUEnableAutomaticChecks" "$INFO_PLIST")
automatic_update=$(/usr/libexec/PlistBuddy -c "Print :SUAutomaticallyUpdate" "$INFO_PLIST")
allows_automatic_updates=$(/usr/libexec/PlistBuddy -c "Print :SUAllowsAutomaticUpdates" "$INFO_PLIST")
echo "Sparkle feed URL = $feed_url"
echo "Sparkle automatic checks = $automatic_checks"
echo "Sparkle automatic background updates = $automatic_update"
echo "Sparkle automatic update option allowed = $allows_automatic_updates"
if [[ "$feed_url" != "$EXPECTED_SPARKLE_FEED_URL" ]]; then
  echo "expected Sparkle feed URL = NO"
  exit 1
fi
if [[ "$public_key" != "$EXPECTED_SPARKLE_PUBLIC_KEY" ]]; then
  echo "expected Sparkle public key = NO"
  exit 1
fi
if [[ "$automatic_checks" != "false" ]]; then
  echo "Sparkle automatic checks disabled = NO"
  exit 1
fi
if [[ "$automatic_update" != "false" ]]; then
  echo "Sparkle automatic background updates disabled = NO"
  exit 1
fi
if [[ "$allows_automatic_updates" != "false" ]]; then
  echo "Sparkle automatic update option disabled = NO"
  exit 1
fi

echo "Sparkle codesign identity:"
/usr/bin/codesign -dvvv "$SPARKLE_FRAMEWORK/Versions/B" 2>&1 | /usr/bin/sed -n '/^Authority=/p'
if /usr/bin/codesign -dvvv "$SPARKLE_FRAMEWORK/Versions/B" 2>&1 | /usr/bin/grep -F "Authority=$EXPECTED_SIGNING_IDENTITY" >/dev/null; then
  echo "Sparkle signing identity stable = YES"
else
  echo "Sparkle signing identity stable = NO"
  exit 1
fi

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
