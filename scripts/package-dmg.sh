#!/bin/zsh
set -euo pipefail

PROJECT_DIR="/Users/gergoterek/Movies/OBS/GPT/HoverClick"
BUILD_SCRIPT="$PROJECT_DIR/scripts/build-app.sh"
VERIFY_SCRIPT="$PROJECT_DIR/scripts/verify-app.sh"
APP_NAME="HoverClick"
APP_PATH="$PROJECT_DIR/$APP_NAME.app"
INFO_PLIST="$PROJECT_DIR/Info.plist"
EXPECTED_BUNDLE_ID="com.gergoterek.HoverClick"
VOLUME_ICON_SOURCE="$PROJECT_DIR/Resources/HoverClickDMGVolumeIcon.icns"
VOLUME_ICON_NAME=".VolumeIcon.icns"
DIST_DIR="$PROJECT_DIR/dist"
TMP_ROOT="$PROJECT_DIR/tmp/package-dmg"
STAGING_DIR="$TMP_ROOT/staging"
MOUNT_POINT=""
ATTACHED_DEVICE=""

detach_image_device() {
  local device="$1"
  local detach_device

  detach_device=$(echo "$device" | /usr/bin/sed -E 's/s[0-9]+$//')
  /usr/bin/hdiutil detach "$detach_device" -quiet
}

cleanup() {
  if [[ -n "${ATTACHED_DEVICE:-}" ]]; then
    detach_image_device "$ATTACHED_DEVICE" || true
  elif [[ -n "${MOUNT_POINT:-}" ]]; then
    /usr/bin/hdiutil detach "$MOUNT_POINT" -quiet || true
  fi
  case "$TMP_ROOT" in
    "$PROJECT_DIR"/tmp/package-dmg)
      /bin/rm -rf "$TMP_ROOT"
      ;;
  esac
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
if [[ -z "$build" ]]; then
  echo "CFBundleVersion is empty."
  exit 1
fi
if [[ ! -f "$VOLUME_ICON_SOURCE" ]]; then
  echo "Missing DMG volume icon source: $VOLUME_ICON_SOURCE"
  exit 1
fi
if ! command -v SetFile >/dev/null; then
  echo "SetFile is required to set the custom DMG volume icon flag."
  exit 1
fi
if ! command -v GetFileInfo >/dev/null; then
  echo "GetFileInfo is required to verify the custom DMG volume icon flag."
  exit 1
fi

DMG_PATH="$DIST_DIR/$APP_NAME-$version-internal.dmg"
RW_DMG_PATH="$TMP_ROOT/$APP_NAME-$version-internal-rw.dmg"

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
/usr/bin/ditto "$APP_PATH" "$STAGING_DIR/$APP_NAME.app"
/bin/ln -s /Applications "$STAGING_DIR/Applications"
/bin/cp "$VOLUME_ICON_SOURCE" "$STAGING_DIR/$VOLUME_ICON_NAME"

/bin/rm -f "$DMG_PATH"

find_mount_point() {
  find_attach_value "$1" "mount-point"
}

find_device_path() {
  find_attach_value "$1" "dev-entry"
}

find_attach_value() {
  local plist_path="$1"
  local key="$2"
  local index
  local candidate

  for index in {0..20}; do
    candidate=$(/usr/libexec/PlistBuddy -c "Print :system-entities:$index:$key" "$plist_path" 2>/dev/null || true)
    if [[ -n "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done

  return 1
}

verify_mounted_dmg() {
  local mount_point="$1"
  local mounted_app="$mount_point/$APP_NAME.app"
  local mounted_info_plist="$mounted_app/Contents/Info.plist"
  local mounted_version
  local mounted_build
  local mounted_bundle_id
  local applications_target
  local volume_icon_flag
  local volume_icon_hidden_flag

  if [[ ! -d "$mounted_app" ]]; then
    echo "Mounted DMG does not contain $APP_NAME.app."
    exit 1
  fi

  mounted_bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$mounted_info_plist")
  if [[ "$mounted_bundle_id" != "$EXPECTED_BUNDLE_ID" ]]; then
    echo "Mounted DMG app bundle id mismatch: $mounted_bundle_id"
    exit 1
  fi

  mounted_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$mounted_info_plist")
  if [[ "$mounted_version" != "$version" ]]; then
    echo "Mounted DMG app version mismatch: $mounted_version"
    exit 1
  fi

  mounted_build=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$mounted_info_plist")
  if [[ "$mounted_build" != "$build" ]]; then
    echo "Mounted DMG app build mismatch: $mounted_build"
    exit 1
  fi

  /usr/bin/codesign --verify --deep --strict --verbose=2 "$mounted_app"

  if [[ ! -L "$mount_point/Applications" ]]; then
    echo "Mounted DMG does not contain the Applications symlink."
    exit 1
  fi

  applications_target=$(/usr/bin/readlink "$mount_point/Applications")
  if [[ "$applications_target" != "/Applications" ]]; then
    echo "Mounted DMG Applications symlink target mismatch: $applications_target"
    exit 1
  fi

  if [[ ! -s "$mount_point/$VOLUME_ICON_NAME" ]]; then
    echo "Mounted DMG does not contain $VOLUME_ICON_NAME."
    exit 1
  fi
  if ! /usr/bin/cmp -s "$VOLUME_ICON_SOURCE" "$mount_point/$VOLUME_ICON_NAME"; then
    echo "Mounted DMG volume icon does not match source: $VOLUME_ICON_SOURCE"
    exit 1
  fi

  volume_icon_flag=$(/usr/bin/GetFileInfo -aC "$mount_point")
  if [[ "$volume_icon_flag" != "1" ]]; then
    echo "Mounted DMG custom volume icon flag is not set."
    exit 1
  fi

  volume_icon_hidden_flag=$(/usr/bin/GetFileInfo -aV "$mount_point/$VOLUME_ICON_NAME")
  if [[ "$volume_icon_hidden_flag" != "1" ]]; then
    echo "Mounted DMG volume icon file is not hidden."
    exit 1
  fi
}

echo "Creating writable internal DMG:"
/usr/bin/hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -fs HFS+ \
  -format UDRW \
  -ov \
  "$RW_DMG_PATH"

echo "Setting DMG presentation metadata:"
mount_plist="$TMP_ROOT/attach-rw.plist"
/usr/bin/hdiutil attach \
  -plist \
  -nobrowse \
  -noautoopen \
  "$RW_DMG_PATH" > "$mount_plist"

MOUNT_POINT=$(find_mount_point "$mount_plist" || true)
ATTACHED_DEVICE=$(find_device_path "$mount_plist" || true)
if [[ -z "$MOUNT_POINT" ]]; then
  echo "DMG mounted without a discoverable mount point."
  exit 1
fi
if [[ -z "$ATTACHED_DEVICE" ]]; then
  echo "DMG mounted without a discoverable device path."
  exit 1
fi

/usr/bin/SetFile -a C "$MOUNT_POINT"
/usr/bin/SetFile -a V "$MOUNT_POINT/$VOLUME_ICON_NAME"
verify_mounted_dmg "$MOUNT_POINT"

detach_image_device "$ATTACHED_DEVICE"
MOUNT_POINT=""
ATTACHED_DEVICE=""

echo "Compressing internal DMG:"
/usr/bin/hdiutil convert "$RW_DMG_PATH" \
  -format UDZO \
  -o "$DMG_PATH" \
  -ov

echo "Verifying DMG:"
/usr/bin/hdiutil verify "$DMG_PATH"

final_mount_plist="$TMP_ROOT/attach-final.plist"
/usr/bin/hdiutil attach \
  -plist \
  -nobrowse \
  -readonly \
  -noautoopen \
  "$DMG_PATH" > "$final_mount_plist"

MOUNT_POINT=$(find_mount_point "$final_mount_plist" || true)
ATTACHED_DEVICE=$(find_device_path "$final_mount_plist" || true)
if [[ -z "$MOUNT_POINT" ]]; then
  echo "Final DMG mounted without a discoverable mount point."
  exit 1
fi
if [[ -z "$ATTACHED_DEVICE" ]]; then
  echo "Final DMG mounted without a discoverable device path."
  exit 1
fi

verify_mounted_dmg "$MOUNT_POINT"

detach_image_device "$ATTACHED_DEVICE"
MOUNT_POINT=""
ATTACHED_DEVICE=""

echo "DMG verification status = passed"
echo "HoverClick version = $version"
echo "HoverClick build = $build"
echo "Final DMG path = $DMG_PATH"
echo "Applications symlink target = /Applications"
echo "Volume icon source = $VOLUME_ICON_SOURCE"
echo "Volume icon file = $VOLUME_ICON_NAME"
echo "Volume custom icon flag = set"
