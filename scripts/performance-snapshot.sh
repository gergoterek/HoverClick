#!/bin/zsh
set -euo pipefail

PROJECT_DIR="/Users/gergoterek/Movies/OBS/GPT/HoverClick"
PROCESS_NAME="HoverClick"
LAUNCH_SCRIPT="$PROJECT_DIR/scripts/run-app.sh"

cd "$PROJECT_DIR"

echo "HoverClick performance snapshot"
echo "timestamp = $(/bin/date '+%Y-%m-%d %H:%M:%S %z')"
echo "project = $PROJECT_DIR"

pid_output=$(/usr/bin/pgrep -x "$PROCESS_NAME" || true)
if [[ -z "$pid_output" ]]; then
  echo "status = not running"
  echo "Launch HoverClick manually for a performance snapshot:"
  echo "$LAUNCH_SCRIPT"
  echo "This script does not launch the app, open UI, change permissions, or change app state."
  exit 2
fi

pids=("${(@f)pid_output}")

echo "status = running"
echo "matching pids = ${pids[*]}"

echo
echo "ps snapshot:"
/bin/ps -o pid,ppid,%cpu,%mem,rss,vsz,etime,stat,command -p "${(j:,:)pids}"

echo
echo "top snapshot:"
for pid in "${pids[@]}"; do
  echo "pid $pid:"
  /usr/bin/top -l 1 -pid "$pid" -stats pid,cpu,mem,time,command 2>/dev/null | /usr/bin/awk -v pid="$pid" '$1 == pid { print }'
done

echo
echo "result = snapshot complete"
echo "Interpret CPU and memory as a local sanity check, not a hard release threshold."
