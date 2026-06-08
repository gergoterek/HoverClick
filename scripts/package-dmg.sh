#!/bin/zsh
set -euo pipefail

PROJECT_DIR="/Users/gergoterek/Movies/OBS/GPT/HoverClick"
BUILD_SCRIPT="$PROJECT_DIR/scripts/build-app.sh"
VERIFY_SCRIPT="$PROJECT_DIR/scripts/verify-app.sh"
APP_NAME="HoverClick"
APP_PATH="$PROJECT_DIR/$APP_NAME.app"
INFO_PLIST="$PROJECT_DIR/Info.plist"
DIST_DIR="$PROJECT_DIR/dist"
TMP_ROOT="$PROJECT_DIR/tmp/package-dmg"
STAGING_DIR="$TMP_ROOT/staging"
MOUNT_POINT=""

cleanup() {
  if [[ -n "${MOUNT_POINT:-}" ]]; then
    /usr/bin/hdiutil detach "$MOUNT_POINT" -quiet || true
  fi
}
trap cleanup EXIT

cd "$PROJECT_DIR"

echo "Building HoverClick:"
"$BUILD_SCRIPT"

echo "Verifying HoverClick app:"
"$VERIFY_SCRIPT"
echo "codesign verification status = passed"

version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST")
build=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST")

if [[ -z "$version" ]]; then
  echo "CFBundleShortVersionString is empty."
  exit 1
fi

DMG_PATH="$DIST_DIR/$APP_NAME-$version-internal.dmg"

case "$TMP_ROOT" in
  "$PROJECT_DIR"/tmp/package-dmg)
    /bin/rm -rf "$TMP_ROOT"
    ;;
  *)
    echo "Refusing to remove unexpected temporary path: $TMP_ROOT"
    exit 1
    ;;
esac

/bin/mkdir -p "$STAGING_DIR" "$DIST_DIR"
/bin/cp -R "$APP_PATH" "$STAGING_DIR/"
/bin/ln -s /Applications "$STAGING_DIR/Applications"

/bin/rm -f "$DMG_PATH"

echo "Creating internal DMG:"
/usr/bin/hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -format UDZO \
  -ov \
  "$DMG_PATH"

echo "Verifying DMG:"
/usr/bin/hdiutil verify "$DMG_PATH"

mount_plist="$TMP_ROOT/attach.plist"
/usr/bin/hdiutil attach \
  -plist \
  -nobrowse \
  -readonly \
  -noautoopen \
  "$DMG_PATH" > "$mount_plist"

for index in {0..20}; do
  candidate=$(/usr/libexec/PlistBuddy -c "Print :system-entities:$index:mount-point" "$mount_plist" 2>/dev/null || true)
  if [[ -n "$candidate" ]]; then
    MOUNT_POINT="$candidate"
    break
  fi
done

if [[ -z "$MOUNT_POINT" ]]; then
  echo "DMG mounted without a discoverable mount point."
  exit 1
fi

if [[ ! -d "$MOUNT_POINT/$APP_NAME.app" ]]; then
  echo "Mounted DMG does not contain $APP_NAME.app."
  exit 1
fi

if [[ ! -L "$MOUNT_POINT/Applications" ]]; then
  echo "Mounted DMG does not contain the Applications symlink."
  exit 1
fi

/usr/bin/hdiutil detach "$MOUNT_POINT" -quiet
MOUNT_POINT=""

echo "DMG verification status = passed"
echo "HoverClick version = $version"
echo "HoverClick build = $build"
echo "Final DMG path = $DMG_PATH"
