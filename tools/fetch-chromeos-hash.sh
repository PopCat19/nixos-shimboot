#!/usr/bin/env bash
#
# Auto-fetch and update all ChromeOS source hashes
#
# Purpose:
#   Reads flake_modules/chromeos-sources.nix, finds every board's URL,
#   fetches the new sha256 via nix-prefetch-url, and replaces the hash inline.
#   Shows progress by default.
#
# Usage:
#   ./tools/update-chromeos-hashes.sh
#
# Dependencies: bash, nix, grep, sed, awk, date, curl
#

set -euo pipefail

# Color codes for pretty output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

SRC_FILE="./flake_modules/chromeos-sources.nix"
BACKUP_DIR="./flake_modules/.backups"
KEEP_BACKUPS=5

[[ -f "$SRC_FILE" ]] || {
  echo -e "${RED}✗ Error: $SRC_FILE not found${NC}" >&2
  exit 1
}

mkdir -p "$BACKUP_DIR"

# Backup with timestamp
STAMP=$(date -u +"%Y%m%d-%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/chromeos-sources.nix.${STAMP}.bak"
cp "$SRC_FILE" "$BACKUP_FILE"
echo -e "${YELLOW}🗃  Backup created at: $BACKUP_FILE${NC}"

# Rotate old backups
mapfile -t old_backups < <(ls -1t "$BACKUP_DIR"/chromeos-sources.nix.*.bak 2>/dev/null || true)
if ((${#old_backups[@]} > KEEP_BACKUPS)); then
  for f in "${old_backups[@]:$KEEP_BACKUPS}"; do
    rm -f -- "$f" && echo -e "${BLUE}🧹 Removed old backup: $(basename "$f")${NC}"
  done
fi

TMPFILE="$(mktemp)"
cp "$SRC_FILE" "$TMPFILE"

# Extract board blocks: URLs per board
echo -e "${BLUE}🔍 Scanning $SRC_FILE for board URLs...${NC}"
mapfile -t entries < <(grep -E 'url *= *"https?://' "$SRC_FILE" | sed -E 's|.*url *= *"([^"]+)".*|\1|')

if ((${#entries[@]} == 0)); then
  echo -e "${RED}✗ No URLs found in $SRC_FILE${NC}" >&2
  exit 2
fi

TOTAL=${#entries[@]}
CURRENT=0
SUCCESSFUL=0
FAILED=0
START_TIME=$(date +%s)

echo -e "${BOLD}Found $TOTAL board(s) to process${NC}"
echo

for url in "${entries[@]}"; do
  CURRENT=$((CURRENT + 1))
  
  # Try to detect board name from preceding line
  board=$(
    awk -v url="$url" '
      $0 ~ url {
        if (prev ~ /^[[:space:]]*[A-Za-z0-9_-]+ *= *{$/) {
          sub(/ *= *.*/, "", prev);
          gsub(/^[[:space:]]+/, "", prev);
          gsub(/[[:space:]]+$/, "", prev);
          print prev;
          exit;
        }
      }
      { prev = $0 }
    ' "$SRC_FILE"
  )
  board="${board:-unknown}"
  
  # Progress header
  echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}[$CURRENT/$TOTAL] Processing: ${YELLOW}$board${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  
  # Show URL (truncated if too long)
  url_display="$url"
  if ((${#url_display} > 60)); then
    url_display="${url:0:57}..."
  fi
  echo -e "  📥 Fetching: ${url_display}"
  
  # Fetch with progress indicator
  hash=""
  if hash=$(nix-prefetch-url "$url" 2>&1); then
    # Extract just the hash if nix-prefetch-url outputs extra info
    hash=$(echo "$hash" | tail -n1 | tr -d '[:space:]')
    
    if [[ -n "$hash" && "$hash" =~ ^[a-z0-9]{52}$ ]]; then
      echo -e "  ${GREEN}✓${NC} Hash: ${hash:0:16}...${hash: -8}"
      SUCCESSFUL=$((SUCCESSFUL + 1))
      
      # Update the file
      awk -v u="$url" -v h="$hash" '
        $0 ~ u { inSection=1; print; next }
        inSection==1 && $0 ~ /sha256 *= *"/ {
          sub(/sha256 *= *"[^"]+"/, "sha256 = \"" h "\"");
          inSection=0;
        }
        { print }
      ' "$TMPFILE" >"${TMPFILE}.new" && mv "${TMPFILE}.new" "$TMPFILE"
    else
      echo -e "  ${RED}✗${NC} Invalid hash format: $hash"
      FAILED=$((FAILED + 1))
    fi
  else
    echo -e "  ${RED}✗${NC} Failed to fetch URL"
    FAILED=$((FAILED + 1))
  fi
  
  # Show running stats
  PERCENT=$((CURRENT * 100 / TOTAL))
  echo -e "  ${BLUE}Progress:${NC} $PERCENT% ($SUCCESSFUL ok, $FAILED failed)"
  echo
done

# Final summary
mv "$TMPFILE" "$SRC_FILE"
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}✅ Processing Complete${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
echo -e "  ${BOLD}Total boards:${NC} $TOTAL"
echo -e "  ${GREEN}Successful:${NC}   $SUCCESSFUL"
if ((FAILED > 0)); then
  echo -e "  ${RED}Failed:${NC}       $FAILED"
fi
echo -e "  ${BLUE}Time elapsed:${NC} ${ELAPSED}s"
echo
echo -e "  ${YELLOW}Backup:${NC} $BACKUP_FILE"
echo
echo -e "${GREEN}✨ Done!${NC}"