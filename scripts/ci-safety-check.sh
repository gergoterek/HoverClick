#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"

cd "$PROJECT_DIR"

section() {
  printf '\n== %s ==\n' "$1"
}

fail() {
  echo "$1" >&2
  exit 1
}

section "Repository"
/usr/bin/git rev-parse --show-toplevel >/dev/null
root=$(/usr/bin/git rev-parse --show-toplevel)
if [[ "$root" != "$PROJECT_DIR" ]]; then
  fail "Unexpected repository root: $root"
fi
echo "Repository root: $root"

section "Public Trace Check"
trace_patterns=(
  "AGENTS"".md"
  "Co""dex"
  "Open""AI"
  "Chat""GPT"
  "save-""work.sh"
  "scripts/""save-""work.sh"
)

trace_hits=""
for pattern in "${trace_patterns[@]}"; do
  matches=$(/usr/bin/git grep -I -n -F -e "$pattern" -- $(/usr/bin/git ls-files) 2>/dev/null || true)
  if [[ -n "$matches" ]]; then
    trace_hits+="${matches}"$'\n'
  fi
done

if [[ -n "$trace_hits" ]]; then
  echo "Forbidden public trace text found in tracked files:"
  printf '%s' "$trace_hits"
  exit 1
fi
echo "No forbidden public trace text found in tracked files."

section "Forbidden Runtime API Check"
runtime_forbidden=(
  "kCGEventMouseMoved"
  "CGEventPost"
  "CGDisplayMoveCursorToPoint"
  "CGWarpMouseCursorPosition"
  "CGAssociateMouseAndMouseCursorPosition"
  "CGEventCreateMouseEvent"
  "kCGEventScrollWheel"
)

runtime_hits=""
for pattern in "${runtime_forbidden[@]}"; do
  matches=$(/usr/bin/grep -n -F "$pattern" HoverClick.mm || true)
  if [[ -n "$matches" ]]; then
    runtime_hits+="${matches}"$'\n'
  fi
done

if [[ -n "$runtime_hits" ]]; then
  echo "Forbidden runtime API text found in HoverClick.mm:"
  printf '%s' "$runtime_hits"
  exit 1
fi
echo "No forbidden runtime API text found in HoverClick.mm."

section "Stable Event Tap Mask Check"
/usr/bin/grep -F "kCGEventLeftMouseDown" HoverClick.mm >/dev/null || fail "Missing kCGEventLeftMouseDown."
/usr/bin/grep -F "kCGEventRightMouseDown" HoverClick.mm >/dev/null || fail "Missing kCGEventRightMouseDown."

mask_block=$(/usr/bin/sed -n '/CGEventMask mask =/,/CGEventTapCreate/p' HoverClick.mm)
echo "$mask_block" | /usr/bin/grep -F "CGEventMaskBit(kCGEventLeftMouseDown)" >/dev/null || fail "Event tap mask is missing left mouse down."
echo "$mask_block" | /usr/bin/grep -F "CGEventMaskBit(kCGEventRightMouseDown)" >/dev/null || fail "Event tap mask is missing right mouse down."
if echo "$mask_block" | /usr/bin/grep -E "MouseMoved|ScrollWheel" >/dev/null; then
  echo "Event tap mask contains mouse-move or scroll entries:"
  echo "$mask_block"
  exit 1
fi
echo "Event tap mask remains left and right mouse down only."

section "Bundle Identifier Check"
if command -v /usr/bin/plutil >/dev/null 2>&1; then
  bundle_id=$(/usr/bin/plutil -extract CFBundleIdentifier raw -o - Info.plist)
elif command -v /usr/bin/python3 >/dev/null 2>&1; then
  bundle_id=$(/usr/bin/python3 - <<'PY'
import plistlib
with open("Info.plist", "rb") as handle:
    print(plistlib.load(handle).get("CFBundleIdentifier", ""))
PY
)
else
  fail "Neither plutil nor python3 is available to read Info.plist."
fi

if [[ "$bundle_id" != "com.gergoterek.HoverClick" ]]; then
  fail "Unexpected bundle identifier: $bundle_id"
fi
echo "Bundle identifier: $bundle_id"

section "Script Syntax Check"
syntax_scripts=(
  scripts/build-app.sh
  scripts/verify-app.sh
  scripts/run-app.sh
  scripts/package-dmg.sh
  scripts/checkpoint.sh
  scripts/ci-safety-check.sh
)

for script in "${syntax_scripts[@]}"; do
  /bin/zsh -n "$script"
  echo "zsh -n passed: $script"
done

section "Generated Artifact Check"
artifact_paths=(
  "HoverClick.app"
  "dist/*.dmg"
  "tmp"
  "logs"
)

tracked_artifacts=$(/usr/bin/git ls-files -- "${artifact_paths[@]}" || true)
if [[ -n "$tracked_artifacts" ]]; then
  echo "Generated artifacts are tracked:"
  echo "$tracked_artifacts"
  exit 1
fi

staged_artifacts=$(/usr/bin/git diff --cached --name-only -- "${artifact_paths[@]}" || true)
if [[ -n "$staged_artifacts" ]]; then
  echo "Generated artifacts are staged:"
  echo "$staged_artifacts"
  exit 1
fi
echo "No generated artifacts are tracked or staged."

section "Documentation Safety Check"
docs_files=(README.md docs/*.md)
doc_hits=""

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  lower=$(printf '%s' "$line" | /usr/bin/tr '[:upper:]' '[:lower:]')
  if [[ "$lower" != *"do not"* && "$lower" != *"does not"* && "$lower" != *"not "* && "$lower" != *"never"* ]]; then
    doc_hits+="${line}"$'\n'
  fi
done < <(/usr/bin/git grep -n -E '(^|[^[:alnum:]_])sudo([^[:alnum:]_]|$)|tccutil[[:space:]]+reset|ad-hoc signing|raw binary|Contents/MacOS/HoverClick' -- "${docs_files[@]}" || true)

release_hits=$(/usr/bin/git grep -n -E 'current.*(Developer ID signed|notarized)|is (Developer ID signed|notarized)' -- "${docs_files[@]}" || true)
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  lower=$(printf '%s' "$line" | /usr/bin/tr '[:upper:]' '[:lower:]')
  if [[ "$lower" != *"not "* && "$lower" != *"notarized public binary release is not available"* && "$lower" != *"future"* && "$lower" != *"deferred"* && "$lower" != *"not current"* ]]; then
    doc_hits+="${line}"$'\n'
  fi
done <<< "$release_hits"

if [[ -n "$doc_hits" ]]; then
  echo "Documentation contains potentially unsafe recommendation text:"
  printf '%s' "$doc_hits"
  exit 1
fi
echo "Documentation safety wording passed targeted checks."

section "Complete"
echo "Static safety checks passed."
