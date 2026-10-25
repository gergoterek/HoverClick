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
  rc=0
  matches=$(/usr/bin/git grep -I -n -F -e "$pattern") || rc=$?
  if (( rc > 1 )); then
    fail "git grep failed (exit $rc) while checking trace pattern"
  fi
  if (( rc == 0 )) && [[ -n "$matches" ]]; then
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
# Every tracked source file is scanned; a new file cannot bring a forbidden call in unchecked.
rc=0
source_list=$(/usr/bin/git ls-files -z -- '*.m' '*.mm' '*.c' '*.cpp' '*.h' '*.swift') || rc=$?
if (( rc != 0 )); then
  fail "git ls-files failed (exit $rc) while listing source files"
fi
source_files=(${(0)source_list})
(( ${#source_files} )) || fail "No tracked source files found for the runtime API check."
echo "Source files checked: ${source_files[*]}"

# Posting, creating or replaying events, moving the cursor and observing mouse movement.
runtime_forbidden=(
  "kCGEventMouseMoved"
  "CGEventPost"
  "CGDisplayMoveCursorToPoint"
  "CGWarpMouseCursorPosition"
  "CGAssociateMouseAndMouseCursorPosition"
  "CGEventCreateMouseEvent"
  "kCGEventScrollWheel"
  "CGEventTapPostEvent"
  "CGPostMouseEvent"
  "CGPostKeyboardEvent"
  "CGPostScrollWheelEvent"
  "CGEventCreate"
  "IOHIDPostEvent"
  "addGlobalMonitorForEventsMatchingMask"
  "addLocalMonitorForEventsMatchingMask"
  "NSEventMaskMouseMoved"
  "NSMouseMovedMask"
)

runtime_hits=""
for pattern in "${runtime_forbidden[@]}"; do
  rc=0
  matches=$(/usr/bin/grep -H -n -F -e "$pattern" -- "${source_files[@]}") || rc=$?
  if (( rc > 1 )); then
    fail "grep failed (exit $rc) while checking runtime API pattern"
  fi
  if (( rc == 0 )) && [[ -n "$matches" ]]; then
    runtime_hits+="${matches}"$'\n'
  fi
done

# A setter changes the original event in place; the name may end its line, with the arguments on the next one.
rc=0
matches=$(/usr/bin/grep -H -n -E 'CGEventSet[[:alnum:]_]*[[:space:]]*(\(|$)' -- "${source_files[@]}") || rc=$?
if (( rc > 1 )); then
  fail "grep failed (exit $rc) while checking event setter calls"
fi
if (( rc == 0 )) && [[ -n "$matches" ]]; then
  runtime_hits+="${matches}"$'\n'
fi

if [[ -n "$runtime_hits" ]]; then
  echo "Forbidden runtime API text found in tracked source files:"
  printf '%s' "$runtime_hits"
  exit 1
fi
echo "No forbidden runtime API text found in HoverClick.mm."

section "Stable Event Tap Mask Check"
/usr/bin/grep -F "kCGEventLeftMouseDown" HoverClick.mm >/dev/null || fail "Missing kCGEventLeftMouseDown."
/usr/bin/grep -F "kCGEventRightMouseDown" HoverClick.mm >/dev/null || fail "Missing kCGEventRightMouseDown."

tap_create_count=$(/usr/bin/grep -c -E 'CGEventTapCreate(ForPid|ForPSN)?[[:space:]]*\(' HoverClick.mm || true)
[[ "$tap_create_count" == "1" ]] || fail "Expected exactly one CGEventTapCreate call, found ${tap_create_count}."

if /usr/bin/grep -n -E 'CGEventTapCreateFor(Pid|PSN)|kCGEventMaskForAllEvents' HoverClick.mm; then
  fail "Event tap uses a per-process tap or the all-events mask."
fi

mask_decl_count=$(/usr/bin/grep -c -E 'CGEventMask[[:space:]]+[[:alnum:]_]+[[:space:]]*=' HoverClick.mm || true)
[[ "$mask_decl_count" == "1" ]] || fail "Expected exactly one CGEventMask assignment, found ${mask_decl_count}."

# The braces keep pipefail from exiting silently when grep finds no match.
mask_bit_count=$({ /usr/bin/grep -o -E 'CGEventMaskBit[[:space:]]*\(' HoverClick.mm || true; } | /usr/bin/wc -l | /usr/bin/tr -d '[:space:]')
[[ "$mask_bit_count" == "2" ]] || fail "Expected exactly two CGEventMaskBit uses, found ${mask_bit_count}."

# An assignment may end its line, with the value on the next one.
if /usr/bin/grep -n -E '(^|[^[:alnum:]_.>])mask[[:space:]]*([|&^+-]|<<|>>)?=([^=]|$)' HoverClick.mm | /usr/bin/grep -v -F 'CGEventMask mask ='; then
  fail "The event tap mask is reassigned after its declaration."
fi

# The mask is passed by value; taking its address would allow a write through a pointer.
if /usr/bin/grep -n -E '&[[:space:]]*mask([^[:alnum:]_]|$)' HoverClick.mm; then
  fail "The event tap mask has its address taken."
fi

expected_mask='CGEventMaskmask=CGEventMaskBit(kCGEventLeftMouseDown)|CGEventMaskBit(kCGEventRightMouseDown);'
mask_statement=$(/usr/bin/awk '/CGEventMask mask =/ { found = 1 } found { printf "%s", $0 } found && /;/ { exit }' HoverClick.mm | /usr/bin/tr -d '[:space:]')
if [[ "$mask_statement" != "$expected_mask" ]]; then
  echo "Event tap mask is not exactly left and right mouse down:"
  echo "$mask_statement"
  exit 1
fi

tap_call=$(/usr/bin/awk '/CGEventTapCreate[[:space:]]*\(/ { found = 1 } found { printf "%s", $0 } found && /\);/ { exit }' HoverClick.mm | /usr/bin/tr -d '[:space:]')
[[ "$tap_call" == *"CGEventTapCreate(kCGHIDEventTap,kCGHeadInsertEventTap,kCGEventTapOptionDefault,mask,HoverClickEventTapCallback,"* ]] || fail "CGEventTapCreate does not pass the checked mask: ${tap_call}"
echo "Event tap mask remains left and right mouse down only."

section "Callback Pass-Through Check"
callback_body=$(/usr/bin/awk '/^static CGEventRef HoverClickEventTapCallback\(/ { found = 1 } found { print } found && /^}/ { exit }' HoverClick.mm)
[[ -n "$callback_body" ]] || fail "HoverClickEventTapCallback not found in HoverClick.mm."

# Each return stands on its own line as `return event;`, except the one `return NULL;` for a NULL event.
rc=0
callback_returns=$(print -r -- "$callback_body" | /usr/bin/grep -E '(^|[^[:alnum:]_])return([^[:alnum:]_]|$)') || rc=$?
if (( rc > 1 )); then
  fail "grep failed (exit $rc) while checking the callback returns"
fi
(( rc == 0 )) || fail "HoverClickEventTapCallback has no return statement."

return_event_count=0
return_null_count=0
while IFS= read -r line; do
  case "${line//[[:space:]]/}" in
    "returnevent;") return_event_count=$(( return_event_count + 1 )) ;;
    "returnNULL;") return_null_count=$(( return_null_count + 1 )) ;;
    *) fail "HoverClickEventTapCallback returns something other than the original event: ${line}" ;;
  esac
done <<< "$callback_returns"
(( return_event_count > 0 )) || fail "HoverClickEventTapCallback never returns the original event."
[[ "$return_null_count" == "1" ]] || fail "Expected exactly one return NULL in HoverClickEventTapCallback, found ${return_null_count}."

callback_flat=$(print -r -- "$callback_body" | /usr/bin/tr -d '[:space:]')
if [[ "$callback_flat" != *"if(event==NULL){returnNULL;"* && "$callback_flat" != *"if(event==NULL)returnNULL;"* ]]; then
  fail "HoverClickEventTapCallback returns NULL other than for a NULL event."
fi

# A write to event, directly or through its address, would make `return event;` return something else.
rc=0
event_writes=$(print -r -- "$callback_body" | /usr/bin/grep -E '(^|[^[:alnum:]_.>])event[[:space:]]*([-|&^+*/%]|<<|>>)?=([^=]|$)|(^|[^&])&[[:space:]]*event([^[:alnum:]_]|$)') || rc=$?
if (( rc > 1 )); then
  fail "grep failed (exit $rc) while checking writes to event"
fi
if (( rc == 0 )); then
  echo "$event_writes"
  fail "HoverClickEventTapCallback writes to event or takes its address."
fi
echo "Event tap callback returns the original event on every path."

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
syntax_scripts=(scripts/*.sh(N))
(( ${#syntax_scripts} )) || fail "No scripts found for syntax check."

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

rc=0
tracked_artifacts=$(/usr/bin/git ls-files -- "${artifact_paths[@]}") || rc=$?
if (( rc != 0 )); then
  fail "git ls-files failed (exit $rc) while checking generated artifacts"
fi
if [[ -n "$tracked_artifacts" ]]; then
  echo "Generated artifacts are tracked:"
  echo "$tracked_artifacts"
  exit 1
fi

rc=0
staged_artifacts=$(/usr/bin/git diff --cached --name-only -- "${artifact_paths[@]}") || rc=$?
if (( rc != 0 )); then
  fail "git diff failed (exit $rc) while checking staged artifacts"
fi
if [[ -n "$staged_artifacts" ]]; then
  echo "Generated artifacts are staged:"
  echo "$staged_artifacts"
  exit 1
fi
echo "No generated artifacts are tracked or staged."

section "Documentation Safety Check"
docs_files=(README.md CLAUDE.md docs/**/*.md(N))
doc_hits=""

rc=0
doc_matches=$(/usr/bin/git grep -n -E '(^|[^[:alnum:]_])sudo([^[:alnum:]_]|$)|tccutil[[:space:]]+reset|ad-hoc signing|raw binary|Contents/MacOS/HoverClick' -- "${docs_files[@]}") || rc=$?
if (( rc > 1 )); then
  fail "git grep failed (exit $rc) while checking documentation wording"
fi
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  lower=$(printf '%s' "$line" | /usr/bin/tr '[:upper:]' '[:lower:]')
  if [[ "$lower" != *"do not"* && "$lower" != *"does not"* && "$lower" != *"not "* && "$lower" != *"never"* ]]; then
    doc_hits+="${line}"$'\n'
  fi
done <<< "$doc_matches"

rc=0
release_hits=$(/usr/bin/git grep -n -E 'current.*(Developer ID signed|notarized)|is (Developer ID signed|notarized)' -- "${docs_files[@]}") || rc=$?
if (( rc > 1 )); then
  fail "git grep failed (exit $rc) while checking release wording"
fi
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
