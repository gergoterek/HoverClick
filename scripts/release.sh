#!/bin/zsh
# Release pipeline. Three explicit steps so that every side effect is visible:
#
#   scripts/release.sh build   --version 1.3.0 --build 45
#       Writes the version into Info.plist, builds and signs dist/build/HoverClick.app,
#       verifies the signature, packages dist/HoverClick-1.3.0.dmg and verifies the image.
#       No network. The project's own HoverClick.app is not touched.
#
#   scripts/release.sh prepare --version 1.3.0 --build 45
#       Everything build does, then signs the DMG with the Sparkle EdDSA key (sign_update) and
#       inserts the item into appcast.xml. Leaves Info.plist, appcast.xml and the release notes
#       for you to review and commit.
#
#   scripts/release.sh publish --version 1.3.0 --build 45
#       Checks that the release commit is committed and pushed, that appcast.xml carries this
#       build with a signature that verifies against the DMG, then creates the GitHub Release
#       v1.3.0 with the DMG and appcast.xml attached and checks that the feed URL serves it.
#       This is the one step with a public side effect, and it also creates the tag.
#
# Release notes: docs/release-notes/<version>.md (Markdown). They become the GitHub Release
# body and, converted to simple HTML, the appcast description.
#
# The Sparkle private key is read from the login keychain (account com.gergoterek.HoverClick,
# see scripts/setup-signing.sh). Set HOVERCLICK_SPARKLE_KEY_FILE to sign from an exported key
# file instead.
set -euo pipefail
source "${0:A:h}/release-config.sh"

DIST_DIR="$PROJECT_DIR/dist"
# The release bundle is built under dist/, not at the project's HoverClick.app, so a locally
# built bundle that is running or under measurement is left alone.
RELEASE_APP="$DIST_DIR/build/$APP_NAME.app"
APPCAST="$PROJECT_DIR/appcast.xml"
PLIST="$PROJECT_DIR/Info.plist"
ICON_SOURCE="$PROJECT_DIR/Resources/HoverClick.icns"
SIGN_UPDATE="$SPARKLE_TOOLS_DIR/sign_update"
GENERATE_KEYS="$SPARKLE_TOOLS_DIR/generate_keys"
MIN_SYSTEM_VERSION=$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$PLIST")

step() { echo; echo "==> $*"; }
die() { echo "release.sh: error: $*" >&2; exit 1; }

command_name="${1:-}"
[[ "$command_name" == (build|prepare|publish) ]] || { sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
shift
version=""
build=""
notes=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) version="$2"; shift 2 ;;
    --build) build="$2"; shift 2 ;;
    --notes) notes="$2"; shift 2 ;;
    *) die "unknown option: $1" ;;
  esac
done
[[ "$version" == <->.<->.<-> ]] || die "--version must look like 1.3.0 (got '$version')"
[[ "$build" == <-> ]] || die "--build must be an integer (got '$build')"
[[ -n "$notes" ]] || notes="$PROJECT_DIR/docs/release-notes/$version.md"
[[ -s "$notes" ]] || die "release notes missing: $notes"

DMG_NAME="$APP_NAME-$version.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"
DOWNLOAD_URL="$RELEASE_DOWNLOAD_BASE/v$version/$DMG_NAME"
TAG="v$version"

# ---- shared checks -------------------------------------------------------------------------

sparkle_sign_args=()
if [[ -n "${HOVERCLICK_SPARKLE_KEY_FILE:-}" ]]; then
  sparkle_sign_args=(--ed-key-file "$HOVERCLICK_SPARKLE_KEY_FILE")
else
  sparkle_sign_args=(--account "$SPARKLE_ACCOUNT")
fi

check_tools() {
  [[ -x "$SIGN_UPDATE" && -x "$GENERATE_KEYS" ]] || die "Sparkle tools missing under $SPARKLE_TOOLS_DIR; run: make -C '$PROJECT_DIR' prepare-sparkle"
  /usr/bin/security find-identity -v -p codesigning | /usr/bin/grep -qF "\"$SIGNING_IDENTITY\"" \
    || die "signing identity '$SIGNING_IDENTITY' not found; run scripts/setup-signing.sh"
}

check_public_key() {
  local plist_key keychain_key
  plist_key=$(/usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" "$PLIST")
  keychain_key=$("$GENERATE_KEYS" --account "$SPARKLE_ACCOUNT" -p 2>/dev/null || true)
  if [[ -z "${HOVERCLICK_SPARKLE_KEY_FILE:-}" ]]; then
    [[ -n "$keychain_key" ]] || die "no Sparkle key for account $SPARKLE_ACCOUNT in the keychain; run scripts/setup-signing.sh"
    [[ "$plist_key" == "$keychain_key" ]] || die "Info.plist SUPublicEDKey ($plist_key) differs from the keychain key ($keychain_key)"
  fi
  echo "SUPublicEDKey = $plist_key"
}

# ---- build ---------------------------------------------------------------------------------

do_build() {
  check_tools
  check_public_key

  step "writing $version (build $build) into Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$PLIST"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build" "$PLIST"
  local feed
  feed=$(/usr/libexec/PlistBuddy -c "Print :SUFeedURL" "$PLIST")
  [[ "$feed" == "$SPARKLE_FEED_URL" ]] || die "Info.plist SUFeedURL is $feed, expected $SPARKLE_FEED_URL"

  step "static gate"
  "$PROJECT_DIR/scripts/source-only-check.sh" >/dev/null
  echo "source-only-check = PASS"

  step "building and signing $APP_NAME.app with '$SIGNING_IDENTITY'"
  /bin/mkdir -p "$DIST_DIR/build"
  /usr/bin/make -C "$PROJECT_DIR" APP="$RELEASE_APP" SIGNING_IDENTITY="$SIGNING_IDENTITY" CODESIGN_OPTIONS= app >/dev/null
  local APP_PATH="$RELEASE_APP"
  /bin/mkdir -p "$APP_PATH/Contents/Resources"
  /bin/cp "$ICON_SOURCE" "$APP_PATH/Contents/Resources/HoverClick.icns"
  /usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --timestamp=none "$APP_PATH"
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_PATH" 2>&1
  local built_version built_build
  built_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
  built_build=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP_PATH/Contents/Info.plist")
  [[ "$built_version" == "$version" && "$built_build" == "$build" ]] || die "built bundle reports $built_version ($built_build)"
  echo "bundle = $built_version (build $built_build), arch = $(/usr/bin/lipo -archs "$APP_PATH/Contents/MacOS/$APP_NAME")"
  /usr/bin/codesign -dvv "$APP_PATH" 2>&1 | /usr/bin/grep -E '^(Authority|Identifier)='

  step "packaging $DMG_NAME"
  /bin/mkdir -p "$DIST_DIR"
  local staging
  staging=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/hoverclick-dmg.XXXXXX")
  /usr/bin/ditto "$APP_PATH" "$staging/$APP_NAME.app"
  /bin/ln -s /Applications "$staging/Applications"
  /bin/rm -f "$DMG_PATH"
  /usr/bin/hdiutil create -volname "$APP_NAME" -srcfolder "$staging" -fs HFS+ -format UDZO -ov -quiet "$DMG_PATH"
  /bin/rm -rf "$staging"
  /usr/bin/hdiutil verify -quiet "$DMG_PATH"

  local mount_dir
  mount_dir=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/hoverclick-mount.XXXXXX")
  /usr/bin/hdiutil attach -readonly -nobrowse -noautoopen -mountpoint "$mount_dir" -quiet "$DMG_PATH"
  local mounted_ok=1
  /usr/bin/codesign --verify --deep --strict "$mount_dir/$APP_NAME.app" || mounted_ok=0
  [[ -L "$mount_dir/Applications" ]] || mounted_ok=0
  /usr/bin/hdiutil detach "$mount_dir" -quiet
  /bin/rmdir "$mount_dir" 2>/dev/null || true
  [[ $mounted_ok == 1 ]] || die "the app inside the DMG does not verify"
  echo "dmg = $DMG_PATH ($(/usr/bin/stat -f %z "$DMG_PATH") bytes, sha256 $(/usr/bin/shasum -a 256 "$DMG_PATH" | /usr/bin/cut -c1-16)...)"
}

# ---- prepare -------------------------------------------------------------------------------

do_prepare() {
  do_build

  step "signing $DMG_NAME with the Sparkle EdDSA key"
  local signature length
  signature=$("$SIGN_UPDATE" "${sparkle_sign_args[@]}" -p "$DMG_PATH")
  length=$(/usr/bin/stat -f %z "$DMG_PATH")
  "$SIGN_UPDATE" "${sparkle_sign_args[@]}" --verify "$DMG_PATH" "$signature" >/dev/null
  echo "edSignature = $signature"
  echo "length = $length"

  step "updating appcast.xml"
  local arch hardware
  arch=$(/usr/bin/lipo -archs "$RELEASE_APP/Contents/MacOS/$APP_NAME")
  hardware=""
  [[ "$arch" == "arm64" ]] && hardware="arm64"
  APPCAST="$APPCAST" VERSION="$version" BUILD="$build" NOTES="$notes" URL="$DOWNLOAD_URL" \
  SIGNATURE="$signature" LENGTH="$length" MINSYS="$MIN_SYSTEM_VERSION" HARDWARE="$hardware" \
  TAG_URL="https://github.com/$GITHUB_REPO/releases/tag/$TAG" \
  /usr/bin/python3 - <<'PY'
import os, re, html, datetime, email.utils

path = os.environ["APPCAST"]
version, build = os.environ["VERSION"], os.environ["BUILD"]
xml = open(path, encoding="utf-8").read()

def markdown_to_html(text):
    out, in_list = [], False
    for line in text.splitlines():
        line = line.rstrip()
        if line.startswith("- "):
            if not in_list:
                out.append("<ul>"); in_list = True
            out.append("<li>%s</li>" % html.escape(line[2:]))
            continue
        if in_list:
            out.append("</ul>"); in_list = False
        if line.startswith("## "):
            out.append("<h2>%s</h2>" % html.escape(line[3:]))
        elif line.startswith("# "):
            out.append("<h1>%s</h1>" % html.escape(line[2:]))
        elif line:
            out.append("<p>%s</p>" % html.escape(line))
    if in_list:
        out.append("</ul>")
    return "\n".join(out)

description = markdown_to_html(open(os.environ["NOTES"], encoding="utf-8").read())
hardware = ""
if os.environ["HARDWARE"]:
    hardware = "            <sparkle:hardwareRequirements>%s</sparkle:hardwareRequirements>\n" % os.environ["HARDWARE"]
item = f"""        <item>
            <title>{version}</title>
            <link>{os.environ["TAG_URL"]}</link>
            <pubDate>{email.utils.format_datetime(datetime.datetime.now().astimezone())}</pubDate>
            <sparkle:version>{build}</sparkle:version>
            <sparkle:shortVersionString>{version}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>{os.environ["MINSYS"]}</sparkle:minimumSystemVersion>
{hardware}            <description><![CDATA[
{description}
            ]]></description>
            <enclosure url="{os.environ["URL"]}" length="{os.environ["LENGTH"]}" type="application/octet-stream" sparkle:edSignature="{os.environ["SIGNATURE"]}"/>
        </item>
"""
# Replace an existing item for the same build (re-running prepare), otherwise insert on top.
pattern = re.compile(r"        <item>\n(?:(?!        </item>\n).)*?<sparkle:version>%s</sparkle:version>.*?        </item>\n" % re.escape(build), re.S)
if pattern.search(xml):
    xml = pattern.sub(lambda m: item, xml, count=1)
    print("replaced the existing item for build %s" % build)
else:
    marker = "        <item>"
    if marker in xml:
        xml = xml.replace(marker, item + marker, 1)
    else:
        xml = xml.replace("    </channel>", item + "    </channel>", 1)
    print("inserted the item for build %s" % build)
open(path, "w", encoding="utf-8").write(xml)
PY
  /usr/bin/xmllint --noout "$APPCAST"
  echo "appcast = $APPCAST"

  step "ready to review and commit"
  (cd "$PROJECT_DIR" && /usr/bin/git status --short --untracked-files=no -- Info.plist appcast.xml "$notes")
  echo "Next: commit Info.plist, appcast.xml and $notes, push, then: scripts/release.sh publish --version $version --build $build"
}

# ---- publish -------------------------------------------------------------------------------

do_publish() {
  check_tools
  cd "$PROJECT_DIR"
  GH=$(command -v gh || true)
  [[ -x "$GH" ]] || die "gh (GitHub CLI) not found on PATH"
  "$GH" auth status >/dev/null 2>&1 || die "gh is not logged in"
  [[ -s "$DMG_PATH" ]] || die "missing $DMG_PATH; run prepare first"

  step "checking the release commit"
  # Everything that ends up in the bundle or the feed must be committed. Documentation may
  # still be in flight in another chat; it is reported, not blocking.
  local dirty other
  dirty=$(/usr/bin/git status --porcelain --untracked-files=no -- Info.plist appcast.xml HoverClick.mm Makefile Resources scripts "$notes")
  [[ -z "$dirty" ]] || die "uncommitted release files:\n$dirty"
  other=$(/usr/bin/git status --porcelain --untracked-files=no)
  [[ -z "$other" ]] || echo "note: uncommitted changes outside the release files:\n$other"
  local plist_version plist_build
  plist_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")
  plist_build=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST")
  [[ "$plist_version" == "$version" && "$plist_build" == "$build" ]] || die "committed Info.plist says $plist_version ($plist_build)"
  local branch head remote_head
  branch=$(/usr/bin/git rev-parse --abbrev-ref HEAD)
  head=$(/usr/bin/git rev-parse HEAD)
  /usr/bin/git fetch -q origin "$branch"
  remote_head=$(/usr/bin/git rev-parse "origin/$branch")
  [[ "$head" == "$remote_head" ]] || die "HEAD $head is not pushed (origin/$branch is $remote_head)"
  echo "branch = $branch @ $head (pushed)"
  ! /usr/bin/git rev-parse -q --verify "refs/tags/$TAG" >/dev/null || die "tag $TAG already exists locally"
  ! "$GH" release view "$TAG" >/dev/null 2>&1 || die "GitHub Release $TAG already exists"

  step "checking appcast.xml against the DMG"
  local signature length appcast_length appcast_url
  local item_xpath="//item[*[local-name()='version']='$build']/enclosure"
  signature=$(/usr/bin/xmllint --xpath "string($item_xpath/@*[local-name()='edSignature'])" "$APPCAST")
  appcast_length=$(/usr/bin/xmllint --xpath "string($item_xpath/@length)" "$APPCAST")
  appcast_url=$(/usr/bin/xmllint --xpath "string($item_xpath/@url)" "$APPCAST")
  [[ -n "$signature" ]] || die "appcast.xml has no item for build $build"
  length=$(/usr/bin/stat -f %z "$DMG_PATH")
  [[ "$appcast_length" == "$length" ]] || die "appcast length $appcast_length differs from the DMG ($length bytes)"
  [[ "$appcast_url" == "$DOWNLOAD_URL" ]] || die "appcast url $appcast_url differs from $DOWNLOAD_URL"
  "$SIGN_UPDATE" "${sparkle_sign_args[@]}" --verify "$DMG_PATH" "$signature" >/dev/null || die "EdDSA signature in appcast.xml does not verify against the DMG"
  local dmg_build
  dmg_build=$(/usr/bin/hdiutil attach -readonly -nobrowse -noautoopen -plist "$DMG_PATH" | /usr/bin/grep -A1 mount-point | /usr/bin/sed -n 's/.*<string>\(.*\)<\/string>.*/\1/p')
  local mounted_build
  mounted_build=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$dmg_build/$APP_NAME.app/Contents/Info.plist")
  /usr/bin/hdiutil detach "$dmg_build" -quiet
  [[ "$mounted_build" == "$build" ]] || die "the DMG contains build $mounted_build, not $build"
  echo "appcast item for build $build verifies against $DMG_NAME"

  step "creating GitHub Release $TAG on $head"
  "$GH" release create "$TAG" "$DMG_PATH" "$APPCAST" \
    --target "$head" \
    --title "$APP_NAME $TAG" \
    --notes-file "$notes" \
    --latest
  /usr/bin/git fetch -q --tags origin

  step "checking the feed"
  local tmp attempt
  tmp=$(/usr/bin/mktemp)
  for attempt in 1 2 3 4 5 6; do
    if /usr/bin/curl -fsSL -o "$tmp" "$SPARKLE_FEED_URL" && /usr/bin/cmp -s "$tmp" "$APPCAST"; then
      echo "feed serves the committed appcast.xml: $SPARKLE_FEED_URL"
      /bin/rm -f "$tmp"
      return 0
    fi
    /bin/sleep 5
  done
  /bin/rm -f "$tmp"
  die "the feed URL does not serve the new appcast yet: $SPARKLE_FEED_URL"
}

case "$command_name" in
  build) do_build ;;
  prepare) do_prepare ;;
  publish) do_publish ;;
esac
