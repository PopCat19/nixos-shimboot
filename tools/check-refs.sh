#!/usr/bin/env bash

# check-refs.sh
#
# Purpose: Validate all file references in markdown docs point to existing files
#
# This module:
# - Scans all .md files for local file path references
# - Verifies each referenced file exists in the repo
# - Validates line-number citations (#L20, #L60-L61) against actual file length
# - Reports errors with file:line context like Rust compiler diagnostics

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source shared colors
# shellcheck source=logging.sh
source "$SCRIPT_DIR/lib/logging.sh"

ERRORS=0
CHECKED=0

error() {
  local md_file="$1"
  local line="$2"
  local ref="$3"
  local msg="$4"
  echo -e "${COLOR_RED}error${COLOR_CLEAR}${COLOR_BOLD}: ${msg}${COLOR_CLEAR}"
  echo -e "  ${COLOR_BLUE}-->${COLOR_CLEAR} ${md_file}:${line}"
  echo -e "   ${COLOR_CYAN}|${COLOR_CLEAR}"
  echo -e " ${line} ${COLOR_CYAN}|${COLOR_CLEAR}   ... ${ref} ..."
  echo
  ERRORS=$((ERRORS + 1))
}

# Resolve a path relative to repo root, stripping anchor and query
resolve_path() {
  local raw="$1"
  # Strip markdown link URL parts: anchor (#...) and query (?...)
  raw="${raw%%#*}"
  raw="${raw%%\?*}"
  # If it's an absolute path in the repo, strip leading /
  raw="${raw#/}"
  echo "$raw"
}

# Check if a path exists (as file or directory)
check_path_exists() {
  local path="$1"
  [[ -f "$REPO_ROOT/$path" ]] || [[ -d "$REPO_ROOT/$path" ]]
}

# Check if a file has at least N lines
check_line_exists() {
  local path="$1"
  local want="$2"
  local have
  have=$(wc -l < "$REPO_ROOT/$path" 2>/dev/null || echo 0)
  (( have >= want ))
}

# Extract a line range from a citation like "#L60" or "#L60-L61"
parse_line_range() {
  local anchor="$1"
  if [[ "$anchor" =~ ^L([0-9]+)$ ]]; then
    echo "${BASH_REMATCH[1]}"
  elif [[ "$anchor" =~ ^L([0-9]+)-L([0-9]+)$ ]]; then
    echo "${BASH_REMATCH[2]}"  # check the max line
  fi
}

# Scan a markdown file for references
scan_file() {
  local md_file="$1"
  local rel="${md_file#$REPO_ROOT/}"
  local line_num=0

  while IFS= read -r line; do
    line_num=$((line_num + 1))

    # === Pattern 1: Inline backtick paths ===
    # Matches: `path/to/file.ext`, `dir/file.nix#L20`, `dir/file.nix#L60-L61`
    while read -r match; do
      [[ -z "$match" ]] && continue
      CHECKED=$((CHECKED + 1))

      local anchor=""
      # Extract #L... anchor if present
      if [[ "$match" =~ ^(.+)#(L[0-9]+(-L[0-9]+)?)$ ]]; then
        match="${BASH_REMATCH[1]}"
        anchor="${BASH_REMATCH[2]}"
      fi

      # Skip glob patterns
      [[ "$match" == *'*'* ]] && continue
      # Skip non-repo paths (URLs, system paths, code snippets, etc.)
      [[ "$match" =~ ^https?:// ]] && continue
      [[ "$match" =~ ^/nix/ ]] && continue
      [[ "$match" =~ ^/run/ ]] && continue
      [[ "$match" =~ ^/proc/ ]] && continue
      [[ "$match" =~ ^/etc/ ]] && continue
      [[ "$match" =~ ^/lib/ ]] && continue
      [[ "$match" =~ ^/home/ ]] && continue
      [[ "$match" =~ ^/dev/ ]] && continue
      [[ "$match" =~ ^~/ ]] && continue
      # Skip Nix module paths (dot-separated identifiers)
      [[ "$match" =~ ^[a-zA-Z_]+\. ]] && continue
      # Skip public keys and other non-path strings
      [[ "$match" =~ :[A-Za-z0-9+/=]{20,} ]] && continue
      # Skip code snippets (= in path means assignment, not a file ref)
      [[ "$match" =~ \ =\  ]] && continue
      # Skip paths with command arguments (space after filename)
      [[ "$match" =~ \ [a-zA-Z\[/\$] ]] && continue
      # Skip build artifacts
      [[ "$match" =~ ^work/ ]] && continue
      # Skip user-config.nix (ambiguous, resolved via context)
      [[ "$match" == "user-config.nix" ]] && continue
      # Skip bare filenames (no directory component, used as examples in context)
      [[ "$match" != */* ]] && continue
      # Must look like a relative path with at least one dir or extension
      [[ "$match" =~ [/.] ]] || continue

      local resolved
      resolved=$(resolve_path "$match")

      # For context.md, resolve relative to the file's directory
      if [[ "$(basename "$md_file")" == "context.md" ]]; then
        local ctx_dir
        ctx_dir="$(dirname "$md_file")"
        ctx_dir="${ctx_dir#$REPO_ROOT/}"
        if [[ -f "$REPO_ROOT/$ctx_dir/$resolved" ]]; then
          resolved="$ctx_dir/$resolved"
        fi
      fi

      if ! check_path_exists "$resolved"; then
        error "$rel" "$line_num" "$match" "referenced file not found: \`$resolved\`"
        continue
      fi

      # Check line range if present
      if [[ -n "$anchor" ]]; then
        local max_line
        max_line=$(parse_line_range "$anchor")
        if [[ -n "$max_line" ]]; then
          if ! check_line_exists "$resolved" "$max_line"; then
            local have
            have=$(wc -l < "$REPO_ROOT/$resolved" 2>/dev/null || echo 0)
            error "$rel" "$line_num" "$match#$anchor" \
              "line reference out of bounds: \`$resolved\` has $have lines, reference wants line $max_line"
          fi
        fi
      fi
    done < <(echo "$line" | grep -oP '`[^`]+`' | sed 's/^`//;s/`$//' || true)

    # === Pattern 2: Markdown links with local paths ===
    # Matches: [text](path/to/file), [text](path/to/file#L20)
    while read -r url; do
      [[ -z "$url" ]] && continue
      CHECKED=$((CHECKED + 1))

      [[ "$url" =~ ^https?:// ]] && continue

      local anchor=""
      if [[ "$url" =~ ^(.+)#(L[0-9]+(-L[0-9]+)?)$ ]]; then
        url="${BASH_REMATCH[1]}"
        anchor="${BASH_REMATCH[2]}"
      fi

      local resolved
      resolved=$(resolve_path "$url")

      if ! check_path_exists "$resolved"; then
        error "$rel" "$line_num" "$url" "linked file not found: \`$resolved\`"
        continue
      fi

      if [[ -n "$anchor" ]]; then
        local max_line
        max_line=$(parse_line_range "$anchor")
        if [[ -n "$max_line" ]]; then
          if ! check_line_exists "$resolved" "$max_line"; then
            local have
            have=$(wc -l < "$REPO_ROOT/$resolved" 2>/dev/null || echo 0)
            error "$rel" "$line_num" "$url#$anchor" \
              "line reference out of bounds: \`$resolved\` has $have lines, reference wants line $max_line"
          fi
        fi
      fi
    done < <(echo "$line" | grep -oP '\]\([^)]+\)' | sed 's/^\](//;s/)$//' || true)

  done < "$md_file"
}

# Find and scan all markdown files (skip .git, conventions, cache)
while IFS= read -r -d '' md; do
  # Skip archived docs
  [[ "$md" == */archive/* ]] && continue
  scan_file "$md"
done < <(find "$REPO_ROOT" -name '*.md' \
  -not -path '*/.git/*' \
  -not -path '*/conventions/*' \
  -not -path '*/.dev-conventions*' \
  -print0)

echo "checked $CHECKED reference(s) across markdown files"

if (( ERRORS > 0 )); then
  echo -e "\n${COLOR_RED}${ERRORS} error(s) found${COLOR_CLEAR}"
  exit 1
fi

echo "all references valid"
