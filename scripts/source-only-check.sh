#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
DEFAULT_BASE="origin/main"
BASE_REF="$DEFAULT_BASE"

usage() {
  echo "Usage: scripts/source-only-check.sh [--base REF]"
  echo
  echo "Runs source-only HoverClick checks without building, signing, launching, packaging, or changing Git state."
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)
      if [[ $# -lt 2 || -z "$2" ]]; then
        echo "Missing reference after --base." >&2
        exit 1
      fi
      BASE_REF="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

cd "$PROJECT_DIR"

root=$(/usr/bin/git rev-parse --show-toplevel)
if [[ "$root" != "$PROJECT_DIR" ]]; then
  echo "Unexpected repository root: $root" >&2
  exit 1
fi

if ! /usr/bin/git rev-parse --verify --quiet "$BASE_REF^{commit}" >/dev/null; then
  echo "Base reference does not resolve to a commit: $BASE_REF" >&2
  exit 1
fi

echo "HoverClick source-only validation"
echo "repository = $root"
echo "branch = $(/usr/bin/git branch --show-current)"
echo "HEAD = $(/usr/bin/git rev-parse HEAD)"
echo "base = $BASE_REF ($(/usr/bin/git rev-parse "$BASE_REF"))"

echo
echo "Checking committed branch diff whitespace:"
/usr/bin/git diff --check "$BASE_REF...HEAD"

echo "Checking unstaged diff whitespace:"
/usr/bin/git diff --check

echo "Checking staged diff whitespace:"
/usr/bin/git diff --cached --check

untracked_files=$(/usr/bin/git ls-files --others --exclude-standard)
if [[ -n "$untracked_files" ]]; then
  echo "Checking untracked source/document text:"
  public_trace_patterns=(
    "AGENTS"".md"
    "Co""dex"
    "Open""AI"
    "Chat""GPT"
    "save-""work.sh"
  )

  while IFS= read -r file; do
    [[ -n "$file" && -f "$file" ]] || continue
    echo "untracked file = $file"

    if /usr/bin/grep -Iq . "$file"; then
      trailing=$(/usr/bin/grep -n -E '[[:blank:]]+$' "$file" || true)
      if [[ -n "$trailing" ]]; then
        echo "Trailing whitespace in untracked file: $file" >&2
        echo "$trailing" >&2
        exit 1
      fi

      for pattern in "${public_trace_patterns[@]}"; do
        if /usr/bin/grep -n -F "$pattern" "$file" >/dev/null; then
          echo "Forbidden public trace text in untracked file: $file ($pattern)" >&2
          exit 1
        fi
      done
    fi

    if [[ "$file" == *.sh ]]; then
      /bin/zsh -n "$file"
    fi
  done <<< "$untracked_files"
fi

echo "Running static safety checks:"
/bin/zsh "$PROJECT_DIR/scripts/ci-safety-check.sh"

sparkle_version=$(/usr/bin/awk -F':=' '/^SPARKLE_VERSION[[:space:]]*:=/ {gsub(/[[:space:]]/, "", $2); print $2; exit}' "$PROJECT_DIR/Makefile")
sparkle_candidates=()
if [[ -n "$sparkle_version" ]]; then
  sparkle_candidates+=("$PROJECT_DIR/tmp/sparkle/Sparkle-$sparkle_version/extracted")
  # A worktree has no tmp/ of its own so fall back to the main checkout's cache.
  common_dir=$(/usr/bin/git rev-parse --git-common-dir)
  main_root="${common_dir:A:h}"
  if [[ "${common_dir:A:t}" == ".git" && "$main_root" != "$PROJECT_DIR" ]]; then
    sparkle_candidates+=("$main_root/tmp/sparkle/Sparkle-$sparkle_version/extracted")
  fi
fi

SPARKLE_FRAMEWORK_ROOT=""
for candidate in "${sparkle_candidates[@]}"; do
  if [[ -d "$candidate/Sparkle.framework" ]]; then
    SPARKLE_FRAMEWORK_ROOT="$candidate"
    break
  fi
done

syntax_state=SKIPPED
if [[ -n "$SPARKLE_FRAMEWORK_ROOT" ]]; then
  echo "Running local syntax-only source check:"
  echo "sparkle framework cache = $SPARKLE_FRAMEWORK_ROOT"
  /usr/bin/clang++ \
    -std=c++17 \
    -fobjc-arc \
    -mmacosx-version-min=12.0 \
    -F"$SPARKLE_FRAMEWORK_ROOT" \
    -fsyntax-only \
    "$PROJECT_DIR/HoverClick.mm"
  echo "syntax-only source check = PASS"
  syntax_state=PASS
else
  echo "syntax-only source check = SKIPPED (local pinned Sparkle framework cache is unavailable; looked in: ${sparkle_candidates[*]:-<SPARKLE_VERSION not found in Makefile>})"
fi

echo
if [[ "$syntax_state" == PASS ]]; then
  echo "static validation = PASS"
else
  echo "static validation = PASS (syntax-only source check SKIPPED)"
fi
echo
echo "This script does not build, sign, launch, or package."
echo "It cannot tell you whether a behavior change works."
echo "Next: scripts/build-app.sh, then scripts/run-app.sh, then test the actual behavior."
