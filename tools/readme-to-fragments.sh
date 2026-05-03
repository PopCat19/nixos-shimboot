#!/usr/bin/env bash

# readme-to-fragments.sh
#
# Purpose: Extract README.md sections back into individual fragment files
#
# This module:
# - Parses BEGIN/END fragment markers in README.md
# - Strips generator-added <details> wrappers for wrapped fragments
# - Writes extracted content to readme_manifest/*.md

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST_DIR="$REPO_ROOT/readme_manifest"
INPUT="$REPO_ROOT/README.md"

# Same list as generate-readme.sh - fragments that get <details> wrappers
DETAILS_FRAGMENTS=(
  "05-quickstart.md"
  "09-bwrap-workaround.md"
  "11-background.md"
  "12-credits.md"
)

# Build set of wrapped fragment names
declare -A WRAPPED
for name in "${DETAILS_FRAGMENTS[@]}"; do
  WRAPPED["$name"]=1
done

current_fragment=""
current_content=""
count=0

while IFS= read -r line; do
  if [[ "$line" =~ ^\<!--\ BEGIN\ fragment:\ (.+)\ --\>$ ]]; then
    current_fragment="${BASH_REMATCH[1]}"
    current_content=""
    continue
  fi

  if [[ "$line" =~ ^\<!--\ END\ fragment:\ (.+)\ --\>$ ]]; then
    end_name="${BASH_REMATCH[1]}"
    if [[ "$end_name" != "$current_fragment" ]]; then
      echo "ERROR: mismatched fragment markers: BEGIN=$current_fragment END=$end_name" >&2
      exit 1
    fi

    # Trim leading blank lines (generator may insert one after BEGIN marker)
    current_content="$(echo "$current_content" | sed '1{/^$/d}')"

    target="$MANIFEST_DIR/$current_fragment"

    if [[ -n "${WRAPPED[$current_fragment]:-}" ]]; then
      # Strip the generator-added <details> wrapper:
      #   <details>\n<summary>Title</summary>\n\n...content...\n</details>
      # Extract content between the blank line after </summary> and </details>
      current_content="$(echo "$current_content" \
        | sed '1{/^<details>$/d}' \
        | sed '1{/^<summary>.*<\/summary>$/d}' \
        | sed '${/^<\/details>$/d}')"

      # Remove leading blank line left after summary
      current_content="$(echo "$current_content" | sed '1{/^$/d}')"

      # Trim trailing blank lines
      current_content="$(echo -n "$current_content" | sed -e :a -e '/^\n*$/{$d;N;};/\n$/ba')"
    fi

    # Ensure trailing newline
    [[ "$current_content" != *$'\n' ]] && current_content="$current_content"$'\n'

    # Only write if content changed
    if [[ -f "$target" ]]; then
      existing="$(cat "$target")"
      [[ "$existing" != *$'\n' ]] && existing="$existing"$'\n'
      if [[ "$existing" == "$current_content" ]]; then
        continue
      fi
    fi

    echo "$current_content" > "$target"
    echo "  wrote $current_fragment"
    count=$((count + 1))
    current_fragment=""
    continue
  fi

  if [[ -n "$current_fragment" ]]; then
    current_content+="$line"$'\n'
  fi
done < "$INPUT"

echo "Extracted $count fragment(s) from $INPUT"

# Update cache so generate-readme.sh doesn't re-trigger
sha256sum "$INPUT" | cut -d' ' -f1 > "$REPO_ROOT/.readme-cache"
