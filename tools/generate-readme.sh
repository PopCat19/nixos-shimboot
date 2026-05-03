#!/usr/bin/env bash

# generate-readme.sh
#
# Purpose: Concatenate readme fragments into README.md with boundary markers
#
# This module:
# - Detects manual README edits and auto-rebases them into fragments first
# - Reads fragments from readme_manifest/ in numeric order
# - Wraps specified fragments in HTML5 <details> sections
# - Emits BEGIN/END markers for reverse extraction
# - Writes combined output to README.md

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST_DIR="$REPO_ROOT/readme_manifest"
OUTPUT="$REPO_ROOT/README.md"
CACHE="$REPO_ROOT/.readme-cache"

REVERSE_SCRIPT="$SCRIPT_DIR/readme-to-fragments.sh"

# Validate manifest enumeration
validate_manifest() {
  local prev=0
  local errors=0

  for fragment in "$MANIFEST_DIR"/*.md; do
    name="$(basename "$fragment")"

    # Must match NN-name.md pattern
    if [[ ! "$name" =~ ^([0-9]{2})-.+\.md$ ]]; then
      echo "ERROR: $name does not match NN-name.md pattern" >&2
      errors=1
      continue
    fi

    num="${BASH_REMATCH[1]}"
    # Strip leading zero for comparison
    num=$((10#$num))

    # Check for gaps
    if (( num != prev + 1 )); then
      echo "ERROR: gap in enumeration — expected $(printf '%02d' $((prev + 1))) after $(printf '%02d' $prev), found $(printf '%02d' $num)" >&2
      errors=1
    fi
    prev=$num
  done

  # Validate DETAILS_FRAGMENTS references exist
  for entry in "${DETAILS_FRAGMENTS[@]}"; do
    file="${entry%%|*}"
    if [[ ! -f "$MANIFEST_DIR/$file" ]]; then
      echo "ERROR: DETAILS_FRAGMENTS references missing file: $file" >&2
      errors=1
    fi
  done

  return $errors
}

# Fragments wrapped in <details> sections: "filename|Title"
DETAILS_FRAGMENTS=(
  "05-quickstart.md|Step-by-Step Guide"
  "09-bwrap-workaround.md|Bwrap / Steam Workaround"
  "11-background.md|Background"
  "12-credits.md|Credits"
)

validate_manifest

# Build associative array for details lookups
declare -A DETAILS_MAP
for entry in "${DETAILS_FRAGMENTS[@]}"; do
  file="${entry%%|*}"
  title="${entry#*|}"
  DETAILS_MAP["$file"]="$title"
done

# Compute hash of current fragments (content-based, order-independent)
fragments_hash() {
  cat "$MANIFEST_DIR"/*.md | sha256sum | cut -d' ' -f1
}

# Detect manual README edits and auto-rebase
if [[ -f "$OUTPUT" ]]; then
  readme_hash="$(sha256sum "$OUTPUT" | cut -d' ' -f1)"

  if [[ -f "$CACHE" ]]; then
    cached_hash="$(cat "$CACHE")"

    if [[ "$readme_hash" != "$cached_hash" ]]; then
      echo "README was edited directly — rebasing into fragments first..."
      bash "$REVERSE_SCRIPT"
    fi
  fi
fi

# Generate README
{
  for fragment in "$MANIFEST_DIR"/*.md; do
    name="$(basename "$fragment")"
    content="$(cat "$fragment")"

    # Ensure trailing newline
    [[ -z "$content" ]] && continue
    [[ "$content" != *$'\n' ]] && content="$content"$'\n'

    echo "<!-- BEGIN fragment: $name -->"

    if [[ -n "${DETAILS_MAP[$name]:-}" ]]; then
      echo "<details>"
      echo "<summary>${DETAILS_MAP[$name]}</summary>"
      echo
      echo "$content"
      echo "</details>"
    else
      echo
      echo "$content"
    fi

    echo "<!-- END fragment: $name -->"
  done
} > "$OUTPUT"

# Store new cache hash
sha256sum "$OUTPUT" | cut -d' ' -f1 > "$CACHE"

echo "Generated $OUTPUT from $MANIFEST_DIR"
