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
README="$REPO_ROOT/README.md"

RED='\033[1;31m'
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

HEAD_COMMIT=$(git -C "$REPO_ROOT" rev-parse --short HEAD)
DRIFT_COUNT=0
STALE_COUNT=0

# Extract all unique commit hashes from README blob URLs
# Pattern: blob/<hash>/...
echo -e "${BOLD}README citations vs HEAD ${CYAN}($HEAD_COMMIT)${RESET}"
echo

while IFS= read -r hash; do
  [[ -z "$hash" ]] && continue

  full_hash=$(git -C "$REPO_ROOT" rev-parse "$hash" 2>/dev/null) || {
    echo -e "  ${RED}✗${RESET} ${hash} ${RED}not in history (force-pushed or rebased away)${RESET}"
    STALE_COUNT=$((STALE_COUNT + 1))
    continue
  }

  # How many commits behind HEAD?
  behind=$(git -C "$REPO_ROOT" rev-list --count "${hash}..HEAD" 2>/dev/null || echo "?")

  if [[ "$behind" == "0" ]]; then
    echo -e "  ${GREEN}✓${RESET} ${hash} ${DIM}(current)${RESET}"
  elif [[ "$behind" == "?" ]]; then
    echo -e "  ${YELLOW}?${RESET} ${hash} ${YELLOW}unable to determine drift${RESET}"
  else
    echo -e "  ${YELLOW}↗${RESET} ${hash} ${YELLOW}${behind} commit(s) behind HEAD${RESET}"
    DRIFT_COUNT=$((DRIFT_COUNT + 1))
  fi

  # Show which fragments reference this hash
  while IFS= read -r fragment; do
    [[ -z "$fragment" ]] && continue
    echo -e "    ${DIM}in ${fragment}${RESET}"
  done < <(grep -l "$hash" "$REPO_ROOT/readme_manifest/"*.md 2>/dev/null | xargs -I{} basename {} || true)

  echo
done < <(grep -oP 'blob/[a-f0-9]+/' "$README" | sed 's|blob/||;s|/||' | sort -u)

# Summary
echo "---"
if (( DRIFT_COUNT == 0 && STALE_COUNT == 0 )); then
  echo -e "${GREEN}all citations current${RESET}"
else
  if (( DRIFT_COUNT > 0 )); then
    echo -e "${YELLOW}${DRIFT_COUNT} citation(s) drifted - run tools/generate-readme.sh after updating fragments${RESET}"
  fi
  if (( STALE_COUNT > 0 )); then
    echo -e "${RED}${STALE_COUNT} citation(s) unreachable - rebased away, update fragments manually${RESET}"
  fi
  exit 1
fi
