#!/bin/zsh
set -euo pipefail

PROJECT_DIR="/Users/gergoterek/Movies/OBS/GPT/HoverClick"
SPARKLE_VERSION="2.9.3"
SPARKLE_ACCOUNT="com.gergoterek.HoverClick"
SPARKLE_TOOLS_DIR="$PROJECT_DIR/tmp/sparkle/Sparkle-$SPARKLE_VERSION/extracted/bin"
GENERATE_APPCAST="$SPARKLE_TOOLS_DIR/generate_appcast"
DEFAULT_WORK_DIR="$PROJECT_DIR/tmp/prepare-appcast"
EXPECTED_RELEASE_URL_PREFIX="https://github.com/gergoterek/HoverClick/releases/download/"

release_dmg=""
download_url=""
version=""
build=""
output_path=""
release_notes=""
work_dir="$DEFAULT_WORK_DIR"
account="$SPARKLE_ACCOUNT"
write_appcast="NO"

usage() {
  cat <<'USAGE'
Usage:
  scripts/prepare-appcast.sh --release-dmg PATH --download-url URL --version VERSION --build BUILD --output PATH [--release-notes PATH] [--write]

Purpose:
  Preflight, and optionally generate, a Sparkle appcast for a future HoverClick release.

Default behavior:
  Dry-run only. Validates required release data, Sparkle tool availability, URL shape,
  DMG filename, size, and SHA-256. It does not create appcast.xml unless --write is passed.

Required release data:
  --release-dmg PATH    Existing final release DMG. This script does not package a DMG.
  --download-url URL    Final public GitHub Release DMG asset URL.
  --version VERSION     CFBundleShortVersionString for the release.
  --build BUILD         CFBundleVersion / Sparkle version for the release.
  --output PATH         Appcast XML output path for the future publish checkout/location.

Optional:
  --release-notes PATH  Release notes file to place next to the DMG for Sparkle.
  --work-dir PATH       Temporary work dir. Defaults to tmp/prepare-appcast.
  --account ACCOUNT     Sparkle Keychain account. Defaults to com.gergoterek.HoverClick.
  --write               Generate appcast.xml locally. Does not upload or publish.
  -h, --help            Show this help.

Safety:
  This script never creates a tag, GitHub Release, DMG, upload, or private key file.
  It uses Sparkle tooling from the pinned local Sparkle 2.9.3 cache and the Keychain account.
USAGE
}

fail() {
  echo "$1" >&2
  exit 1
}

require_value() {
  local option="$1"
  local value="${2:-}"
  [[ -n "$value" ]] || fail "Missing value for $option."
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release-dmg)
      require_value "$1" "${2:-}"
      release_dmg="$2"
      shift 2
      ;;
    --download-url)
      require_value "$1" "${2:-}"
      download_url="$2"
      shift 2
      ;;
    --version)
      require_value "$1" "${2:-}"
      version="$2"
      shift 2
      ;;
    --build)
      require_value "$1" "${2:-}"
      build="$2"
      shift 2
      ;;
    --output)
      require_value "$1" "${2:-}"
      output_path="$2"
      shift 2
      ;;
    --release-notes)
      require_value "$1" "${2:-}"
      release_notes="$2"
      shift 2
      ;;
    --work-dir)
      require_value "$1" "${2:-}"
      work_dir="$2"
      shift 2
      ;;
    --account)
      require_value "$1" "${2:-}"
      account="$2"
      shift 2
      ;;
    --write)
      write_appcast="YES"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

[[ -n "$release_dmg" ]] || fail "Missing --release-dmg."
[[ -n "$download_url" ]] || fail "Missing --download-url."
[[ -n "$version" ]] || fail "Missing --version."
[[ -n "$build" ]] || fail "Missing --build."
[[ -n "$output_path" ]] || fail "Missing --output."

cd "$PROJECT_DIR"

[[ -f "$release_dmg" ]] || fail "Release DMG not found: $release_dmg"
[[ "$release_dmg" == *.dmg ]] || fail "Release artifact must be a DMG: $release_dmg"
[[ "$download_url" == "$EXPECTED_RELEASE_URL_PREFIX"* ]] || fail "Download URL must be a HoverClick GitHub Release asset URL."
[[ "$download_url" == "$EXPECTED_RELEASE_URL_PREFIX""v$version/"* ]] || fail "Download URL must use the matching v$version GitHub Release path."
[[ "$download_url" == */"${release_dmg:t}" ]] || fail "Download URL filename must match DMG filename: ${release_dmg:t}"
[[ -z "$release_notes" || -f "$release_notes" ]] || fail "Release notes file not found: $release_notes"

if [[ ! -x "$GENERATE_APPCAST" ]]; then
  fail "Missing pinned Sparkle generate_appcast tool: $GENERATE_APPCAST
Run the normal pinned Sparkle preparation/build workflow before preparing a real appcast."
fi

size=$(/usr/bin/stat -f%z "$release_dmg")
sha256=$(/usr/bin/shasum -a 256 "$release_dmg" | /usr/bin/awk '{print $1}')
download_url_prefix="${download_url%/*}/"
archive_name="${release_dmg:t}"

echo "HoverClick appcast preflight"
echo "release DMG = $release_dmg"
echo "release DMG filename = $archive_name"
echo "download URL = $download_url"
echo "download URL prefix = $download_url_prefix"
echo "version = $version"
echo "build = $build"
echo "size = $size"
echo "sha256 = $sha256"
echo "Sparkle account = $account"
echo "Sparkle tool = $GENERATE_APPCAST"
echo "output path = $output_path"

if [[ "$write_appcast" != "YES" ]]; then
  echo "dry run = YES"
  echo "No appcast was written. Pass --write after the real release DMG and public URL exist."
  exit 0
fi

case "$work_dir" in
  "$PROJECT_DIR"/tmp/prepare-appcast|"$PROJECT_DIR"/tmp/prepare-appcast/*)
    /bin/rm -rf "$work_dir"
    ;;
  *)
    fail "Refusing to remove unexpected work dir outside tmp/prepare-appcast: $work_dir"
    ;;
esac

archives_dir="$work_dir/archives"
/bin/mkdir -p "$archives_dir" "${output_path:h}"
/bin/cp "$release_dmg" "$archives_dir/$archive_name"
if [[ -n "$release_notes" ]]; then
  notes_ext="${release_notes:e}"
  /bin/cp "$release_notes" "$archives_dir/${archive_name:r}.$notes_ext"
fi

"$GENERATE_APPCAST" \
  --account "$account" \
  --download-url-prefix "$download_url_prefix" \
  --maximum-versions 0 \
  -o appcast.xml \
  "$archives_dir"

generated_appcast="$archives_dir/appcast.xml"
[[ -s "$generated_appcast" ]] || fail "Sparkle did not create expected appcast: $generated_appcast"

if command -v /usr/bin/xmllint >/dev/null 2>&1; then
  /usr/bin/xmllint --noout "$generated_appcast"
fi

/usr/bin/grep -F "$download_url" "$generated_appcast" >/dev/null || fail "Generated appcast does not contain the expected download URL."
/usr/bin/grep -F "sparkle:edSignature" "$generated_appcast" >/dev/null || fail "Generated appcast is missing sparkle:edSignature."
/usr/bin/grep -F "length=\"$size\"" "$generated_appcast" >/dev/null || fail "Generated appcast does not contain expected enclosure length."
/usr/bin/grep -F "sparkle:version=\"$build\"" "$generated_appcast" >/dev/null || fail "Generated appcast does not contain expected build."
/usr/bin/grep -F "$version" "$generated_appcast" >/dev/null || fail "Generated appcast does not contain expected version."

/bin/cp "$generated_appcast" "$output_path"
echo "appcast written = $output_path"
echo "No upload, tag, GitHub Release, DMG packaging, or publish step was performed."
