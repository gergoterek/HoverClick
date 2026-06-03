#!/bin/zsh
set -euo pipefail

PROJECT_DIR="/Users/gergoterek/Movies/OBS/GPT/HoverClick"
APP_PATH="$PROJECT_DIR/HoverClick.app"
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

/usr/bin/make -C "$PROJECT_DIR" app

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
