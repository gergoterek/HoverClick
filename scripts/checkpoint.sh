#!/bin/zsh
set -euo pipefail

PROJECT_DIR="/Users/gergoterek/Movies/OBS/GPT/HoverClick"
BUILD_SCRIPT="$PROJECT_DIR/scripts/build-app.sh"
VERIFY_SCRIPT="$PROJECT_DIR/scripts/verify-app.sh"

TARGET_BRANCH=""
ALLOW_MAIN=0
COMMIT_MESSAGE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch)
      if [[ $# -lt 2 || -z "$2" ]]; then
        echo "Missing branch name after --branch."
        exit 1
      fi
      TARGET_BRANCH="$2"
      shift 2
      ;;
    --allow-main)
      ALLOW_MAIN=1
      shift
      ;;
    --*)
      echo "Unknown option: $1"
      exit 1
      ;;
    *)
      if [[ -z "$COMMIT_MESSAGE" ]]; then
        COMMIT_MESSAGE="$1"
      else
        echo "Unexpected extra argument: $1"
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$COMMIT_MESSAGE" ]]; then
  COMMIT_MESSAGE="chore: checkpoint HoverClick work $(/bin/date '+%Y-%m-%d %H:%M:%S')"
fi

slugify() {
  local raw="$1"
  local slug
  slug=$(printf '%s' "$raw" \
    | /usr/bin/tr '[:upper:]' '[:lower:]' \
    | /usr/bin/sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g' \
    | /usr/bin/cut -c 1-48 \
    | /usr/bin/sed -E 's/-+$//')

  if [[ -z "$slug" ]]; then
    slug="hoverclick-work"
  fi

  printf '%s' "$slug"
}

cd "$PROJECT_DIR"

echo "Current git status:"
/usr/bin/git status --short --branch

current_branch=$(/usr/bin/git branch --show-current)
if [[ -z "$current_branch" ]]; then
  echo "Refusing to checkpoint from detached HEAD."
  exit 1
fi

if [[ "$current_branch" == "main" && "$ALLOW_MAIN" -ne 1 ]]; then
  if [[ -z "$TARGET_BRANCH" ]]; then
    TARGET_BRANCH="work/$(slugify "$COMMIT_MESSAGE")-$(/bin/date '+%Y%m%d-%H%M%S')"
  fi

  echo "Creating or switching to task branch: $TARGET_BRANCH"
  if /usr/bin/git show-ref --verify --quiet "refs/heads/$TARGET_BRANCH"; then
    /usr/bin/git switch "$TARGET_BRANCH"
  else
    /usr/bin/git switch -c "$TARGET_BRANCH"
  fi
elif [[ "$current_branch" == "main" && "$ALLOW_MAIN" -eq 1 ]]; then
  echo "Checkpointing directly on main because --allow-main was provided."
elif [[ "$current_branch" != "main" ]]; then
  if [[ -n "$TARGET_BRANCH" && "$TARGET_BRANCH" != "$current_branch" ]]; then
    echo "Already on task branch '$current_branch'; ignoring requested branch '$TARGET_BRANCH'."
  fi
  echo "Using current task branch: $current_branch"
fi

current_branch=$(/usr/bin/git branch --show-current)
echo "Checkpoint branch: $current_branch"

echo "Building HoverClick:"
"$BUILD_SCRIPT"

echo "Verifying HoverClick codesigning:"
"$VERIFY_SCRIPT"

echo "Staging intentional project files:"
/usr/bin/git add -u -- .

/usr/bin/git add -A -- \
  .gitignore \
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

commit_hash=$(/usr/bin/git rev-parse HEAD)

echo "Pushing to origin HEAD:"
/usr/bin/git push -u origin HEAD
echo "Push result: origin/$current_branch updated."

echo "Branch name: $current_branch"
echo "Commit hash: $commit_hash"

echo "Final git status:"
/usr/bin/git status --short --branch

echo "Last commits:"
/usr/bin/git log --oneline -5
