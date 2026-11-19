#!/bin/zsh
# End-to-end check of Background Tab Hover against the live windows. Builds
# scripts/tab-hover-harness.mm around the feature's own code, cut from HoverClick.mm, and runs it.
# A supported browser must be running with at least three tabs the pointer can reach; the terminal
# needs the Accessibility permission. A card appears on screen for a few seconds.
# After the tabs it rests on named controls of other applications' background windows, where the
# pointer can reach any, and checks the card there too.
#
# Usage: scripts/tab-hover-harness.sh [--shots <directory>] [--source <HoverClick.mm>]
#   --shots   save a screenshot of the first card of each window (needs Screen Recording)
#   --source  check another copy of HoverClick.mm, e.g. an older checkout, as a control
set -euo pipefail

source "${0:A:h}/release-config.sh"

src="$PROJECT_DIR/HoverClick.mm"
shots=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --shots) shots="$2"; shift 2 ;;
    --source) src="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 64 ;;
  esac
done

out="$PROJECT_DIR/tmp/tab-hover-harness"
/bin/mkdir -p "$out"

start=$(/usr/bin/grep -n '^// Background Tab Hover. Chromium-based browsers register' "$src" | /usr/bin/head -1 | /usr/bin/cut -d: -f1)
end=$(/usr/bin/grep -n '^@implementation HoverClickAppDelegate {' "$src" | /usr/bin/head -1 | /usr/bin/cut -d: -f1)
if [[ -z "$start" || -z "$end" ]]; then
  echo "Background Tab Hover block not found in $src" >&2
  exit 1
fi
end=$((end - 1))

# The only two swaps: where the pointer is and which application is frontmost.
/usr/bin/sed -n "${start},${end}p" "$src" \
  | /usr/bin/sed -e 's/\[NSEvent mouseLocation\]/HarnessMouseLocation()/g' \
                 -e 's/\[NSEvent pressedMouseButtons\]/((NSUInteger)0)/g' \
                 -e 's/NSWorkspace\.sharedWorkspace\.frontmostApplication\.processIdentifier/HarnessFrontmostPid()/g' \
  > "$out/tab-hover-slice.inc"

/usr/bin/clang++ -std=c++17 -fobjc-arc -mmacosx-version-min=12.0 -Wall -Wextra \
  -I "$out" -framework Cocoa -framework ApplicationServices \
  "$PROJECT_DIR/scripts/tab-hover-harness.mm" -o "$out/tab-hover-harness"

if [[ -n "$shots" ]]; then
  /bin/mkdir -p "$shots"
  "$out/tab-hover-harness" "$shots"
else
  "$out/tab-hover-harness"
fi
