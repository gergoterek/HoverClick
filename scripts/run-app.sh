#!/bin/zsh
set -euo pipefail

source "${0:A:h}/release-config.sh"
PROCESS_NAME="HoverClick"

if /usr/bin/pgrep -x "$PROCESS_NAME" >/dev/null; then
  /usr/bin/pkill -x "$PROCESS_NAME"
  for _ in {1..30}; do
    if ! /usr/bin/pgrep -x "$PROCESS_NAME" >/dev/null; then
      break
    fi
    /bin/sleep 0.2
  done
fi

"$PROJECT_DIR/scripts/build-app.sh"

/usr/bin/open "$APP_PATH"

for _ in {1..50}; do
  count=$((/usr/bin/pgrep -x "$PROCESS_NAME" || true) | /usr/bin/wc -l | /usr/bin/tr -d ' ')
  if [[ "$count" == "1" ]]; then
    echo "HoverClick is running as one .app-launched process."
    exit 0
  fi
  /bin/sleep 0.2
done

count=$((/usr/bin/pgrep -x "$PROCESS_NAME" || true) | /usr/bin/wc -l | /usr/bin/tr -d ' ')
echo "Expected exactly one HoverClick process, found: $count" >&2
exit 1
