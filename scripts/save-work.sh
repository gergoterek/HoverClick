#!/bin/zsh
set -euo pipefail

PROJECT_DIR="/Users/gergoterek/Movies/OBS/GPT/HoverClick"
BUILD_SCRIPT="$PROJECT_DIR/scripts/build-app.sh"
VERIFY_SCRIPT="$PROJECT_DIR/scripts/verify-app.sh"

if [[ $# -gt 0 && -n "$1" ]]; then
  COMMIT_MESSAGE="$1"
else
  COMMIT_MESSAGE="chore: save HoverClick work $(/bin/date '+%Y-%m-%d %H:%M:%S')"
fi

cd "$PROJECT_DIR"

echo "Current git status:"
/usr/bin/git status --short --branch

current_branch=$(/usr/bin/git branch --show-current)
if [[ "$current_branch" != "main" ]]; then
  echo "Refusing to save work from branch '$current_branch'. Switch to main first."
  exit 1
fi

echo "Building HoverClick:"
"$BUILD_SCRIPT"

echo "Verifying HoverClick codesigning:"
"$VERIFY_SCRIPT"

echo "Staging intentional project files:"
/usr/bin/git add -- \
  .gitignore \
  AGENTS.md \
  README.md \
  Makefile \
  Info.plist \
  HoverClick.mm \
  docs \
  scripts

forbidden_staged=$(/usr/bin/git diff --cached --name-only -- \
  'HoverClick.app' \
  'DerivedData' \
  'build' \
  'logs' \
  'tmp' \
  '*.dSYM' \
  'dist/*.dmg' \
  '*.log' \
  '*.tmp' || true)

if [[ -n "$forbidden_staged" ]]; then
  echo "Refusing to commit generated artifacts:"
  echo "$forbidden_staged"
  exit 1
fi

echo "Staged files:"
/usr/bin/git diff --cached --name-status

if /usr/bin/git diff --cached --quiet; then
  echo "No staged source, documentation, or script changes to commit."
else
  /usr/bin/git commit -m "$COMMIT_MESSAGE"
fi

echo "Pushing to origin main:"
/usr/bin/git push origin main

echo "Final git status:"
/usr/bin/git status --short --branch

echo "Last commits:"
/usr/bin/git log --oneline -5
