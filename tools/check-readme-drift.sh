#!/usr/bin/env bash

# check-readme-drift.sh
#
# Purpose: Detect stale commit citations in README.md against current HEAD
#
# This module:
# - Extracts all commit hashes referenced in README permalinks
# - Compares each cited commit to current HEAD
# - Reports how many commits behind each citation has drifted
# - Flags citations from commits no longer in history (rebased/force-pushed away)
# - Suggests which fragments need updating

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source shared colors
# shellcheck source=logging.sh
source "$SCRIPT_DIR/lib/logging.sh"

README="$REPO_ROOT/README.md"

HEAD_COMMIT=$(git -C "$REPO_ROOT" rev-parse --short HEAD)
DRIFT_COUNT=0
STALE_COUNT=0

# Extract all unique commit hashes from README blob URLs
# Pattern: blob/<hash>/...
echo -e "${COLOR_BOLD}README citations vs HEAD ${COLOR_CYAN}($HEAD_COMMIT)${COLOR_CLEAR}"
echo

while IFS= read -r hash; do
  [[ -z "$hash" ]] && continue

  full_hash=$(git -C "$REPO_ROOT" rev-parse "$hash" 2>/dev/null) || {
    echo -e "  ${COLOR_RED}✗${COLOR_CLEAR} ${hash} ${COLOR_RED}not in history (force-pushed or rebased away)${COLOR_CLEAR}"
    STALE_COUNT=$((STALE_COUNT + 1))
    continue
  }

  # How many commits behind HEAD?
  behind=$(git -C "$REPO_ROOT" rev-list --count "${hash}..HEAD" 2>/dev/null || echo "?")

  if [[ "$behind" == "0" ]]; then
    echo -e "  ${COLOR_GREEN}✓${COLOR_CLEAR} ${hash} ${COLOR_DIM}(current)${COLOR_CLEAR}"
  elif [[ "$behind" == "?" ]]; then
    echo -e "  ${COLOR_YELLOW}?${COLOR_CLEAR} ${hash} ${COLOR_YELLOW}unable to determine drift${COLOR_CLEAR}"
  else
    echo -e "  ${COLOR_YELLOW}↗${COLOR_CLEAR} ${hash} ${COLOR_YELLOW}${behind} commit(s) behind HEAD${COLOR_CLEAR}"
    DRIFT_COUNT=$((DRIFT_COUNT + 1))
  fi

  # Show which fragments reference this hash
  while IFS= read -r fragment; do
    [[ -z "$fragment" ]] && continue
    echo -e "    ${COLOR_DIM}in ${fragment}${COLOR_CLEAR}"
  done < <(grep -l "$hash" "$REPO_ROOT/readme_manifest/"*.md 2>/dev/null | xargs -I{} basename {} || true)

  echo
done < <(grep -oP 'blob/[a-f0-9]+/' "$README" | sed 's|blob/||;s|/||' | sort -u)

# Summary
echo "---"
if (( DRIFT_COUNT == 0 && STALE_COUNT == 0 )); then
  echo -e "${COLOR_GREEN}all citations current${COLOR_CLEAR}"
else
  if (( DRIFT_COUNT > 0 )); then
    echo -e "${COLOR_YELLOW}${DRIFT_COUNT} citation(s) drifted - run tools/generate-readme.sh after updating fragments${COLOR_CLEAR}"
  fi
  if (( STALE_COUNT > 0 )); then
    echo -e "${COLOR_RED}${STALE_COUNT} citation(s) unreachable - rebased away, update fragments manually${COLOR_CLEAR}"
  fi
  exit 1
fi
