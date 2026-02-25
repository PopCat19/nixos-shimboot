#!/usr/bin/env bash

# fetch-recovery.sh
#
# Purpose: Fetch ChromeOS recovery image hashes and update chromeos-sources.nix
#
# This module:
# - Downloads recovery metadata from ChromeOS release APIs
# - Computes Nix-compatible SRI hashes for recovery images
# - Patches chromeos-sources.nix in place with backup/restore on failure

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly SOURCES_FILE="$PROJECT_ROOT/flake_modules/chromeos-sources.nix"
readonly BACKUP_DIR="$PROJECT_ROOT/.backup"
readonly TEMP_DIR="$(mktemp -d)"

readonly RELEASES_URL="https://cdn.jsdelivr.net/gh/MercuryWorkshop/chromeos-releases-data/data.json"
readonly GOOGLE_API_URL="https://dl.google.com/dl/edgedl/chromeos/recovery/recovery2.json"

readonly SUPPORTED_BOARDS=(
  "dedede" "octopus" "zork" "nissa" "hatch"
  "grunt" "snappy"
)

DRY_RUN=false
VERBOSE=false
SPECIFIC_BOARD=""

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log_info()    { printf "${BLUE}[INFO]${NC} %s\n" "$*" >&2; }
log_warn()    { printf "${YELLOW}[WARN]${NC} %s\n" "$*" >&2; }
log_error()   { printf "${RED}[ERROR]${NC} %s\n" "$*" >&2; }
log_success() { printf "${GREEN}[OK]${NC} %s\n" "$*" >&2; }
log_verbose() { [[ "$VERBOSE" == true ]] && log_info "$@" || true; }

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Fetch ChromeOS recovery image hashes and update chromeos-sources.nix.

Options:
    -h, --help      Show this help message
    -d, --dry-run   Show changes without modifying files
    -v, --verbose   Enable verbose output
    -b, --board B   Process only board B

Examples:
    $0                    # Process all boards
    $0 --dry-run          # Show what would change
    $0 -b corsola         # Process only corsola
EOF
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)    usage; exit 0 ;;
      -d|--dry-run) DRY_RUN=true; shift ;;
      -v|--verbose) VERBOSE=true; shift ;;
      -b|--board)
        SPECIFIC_BOARD="$2"
        if [[ ! " ${SUPPORTED_BOARDS[*]} " =~ [[:space:]]${SPECIFIC_BOARD}[[:space:]] ]]; then
          log_error "Unsupported board: $SPECIFIC_BOARD"
          log_error "Supported: ${SUPPORTED_BOARDS[*]}"
          exit 1
        fi
        shift 2
        ;;
      *) log_error "Unknown option: $1"; usage; exit 1 ;;
    esac
  done
}

cleanup() {
  rm -rf "$TEMP_DIR"
  log_verbose "Cleaned up $TEMP_DIR"
}

backup_sources() {
  mkdir -p "$BACKUP_DIR"
  local backup_file="$BACKUP_DIR/chromeos-sources.nix.$(date +%Y%m%d_%H%M%S)"
  cp "$SOURCES_FILE" "$backup_file"
  log_info "Backup: $backup_file"
  echo "$backup_file"
}

restore_backup() {
  local backup_file="$1"
  if [[ -f "$backup_file" ]]; then
    cp "$backup_file" "$SOURCES_FILE"
    log_info "Restored from $backup_file"
  fi
}

# Fetches release data, writes normalized JSON to stdout: { "board": { "url": "...", "sha256": "..." } }
fetch_releases_data() {
  local out="$TEMP_DIR/releases.json"

  log_info "Fetching ChromeOS releases data..."
  if curl -fsSL --connect-timeout 10 --max-time 60 "$RELEASES_URL" -o "$out" 2>/dev/null &&
     jq empty "$out" 2>/dev/null; then
    local count
    count=$(jq 'keys | length' "$out")
    log_info "Releases data: $count boards"
    return 0
  fi

  log_warn "Releases API unavailable, falling back to Google recovery API..."
  local raw="$TEMP_DIR/google-raw.json"
  if ! curl -fsSL --connect-timeout 10 --max-time 60 "$GOOGLE_API_URL" -o "$raw" 2>/dev/null; then
    log_error "Both APIs unreachable"
    return 1
  fi

  # Normalize Google format into the same structure
  jq 'reduce .[] as $item ({};
    if $item.channel == "stable-channel" then
      .[$item.board] = {url: $item.url, sha256: $item.sha256}
    else . end
  )' "$raw" > "$out"

  log_info "Google API data normalized"
}

get_board_recovery_info() {
  local board="$1"
  local data_file="$TEMP_DIR/releases.json"

  local url hash

  # Attempt structured lookup (releases format has nested images array)
  url=$(jq -r --arg b "$board" \
    '(.[$b].images[]? // empty) | select(.channel == "stable-channel") | .url' \
    "$data_file" 2>/dev/null | head -1)

  # Fallback to flat format (normalized Google data)
  if [[ -z "$url" || "$url" == "null" ]]; then
    url=$(jq -r --arg b "$board" '.[$b].url // empty' "$data_file" 2>/dev/null)
    hash=$(jq -r --arg b "$board" '.[$b].sha256 // empty' "$data_file" 2>/dev/null)
  fi

  if [[ -z "$url" || "$url" == "null" ]]; then
    log_error "No recovery URL for board: $board"
    return 1
  fi

  echo "${url}|${hash:-}"
}

compute_sri_hash() {
  local url="$1" board="$2"
  local temp_file="$TEMP_DIR/${board}-recovery.bin"

  log_info "Downloading recovery image for $board to compute hash..."
  if ! curl -fL --progress-bar "$url" -o "$temp_file"; then
    log_error "Download failed for $board"
    return 1
  fi

  local sri_hash
  sri_hash=$(nix hash file --type sha256 "$temp_file")
  rm -f "$temp_file"

  if [[ -z "$sri_hash" ]]; then
    log_error "Hash computation failed for $board"
    return 1
  fi

  echo "$sri_hash"
}

# Avoid double-prefixing: nix hash file returns SRI (sha256-...), raw hex does not
normalize_hash() {
  local hash="$1"
  if [[ "$hash" == sha256-* ]]; then
    echo "$hash"
  elif [[ "$hash" =~ ^[0-9a-fA-F]{64}$ ]]; then
    # Convert raw hex to SRI via nix
    nix hash to-sri --type sha256 "$hash"
  else
    echo "sha256-$hash"
  fi
}

update_sources_file() {
  local board="$1" url="$2" hash="$3"

  if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY RUN] $board"
    log_info "  url   = $url"
    log_info "  hash  = $hash"
    return 0
  fi

  local tmp="${SOURCES_FILE}.tmp"

  awk -v board="$board" -v url="$url" -v hash="$hash" '
    BEGIN { in_board = 0 }
    /^[[:space:]]*"/ && $0 ~ ("\"" board "\"" "[[:space:]]*=[[:space:]]*\\{") {
      in_board = 1
    }
    in_board && /url[[:space:]]*=/ {
      sub(/url = "[^"]*"/, "url = \"" url "\"")
    }
    in_board && /sha256[[:space:]]*=/ {
      sub(/sha256 = "[^"]*"/, "sha256 = \"" hash "\"")
      in_board = 0
    }
    { print }
  ' "$SOURCES_FILE" > "$tmp"

  mv "$tmp" "$SOURCES_FILE"
  log_success "Updated $board"
}

validate_sources_file() {
  [[ "$DRY_RUN" == true ]] && return 0

  log_info "Validating nix syntax..."
  if ! nix-instantiate --parse "$SOURCES_FILE" >/dev/null 2>&1; then
    log_error "Nix syntax validation failed"
    return 1
  fi

  log_success "Nix syntax valid"
  return 0
}

process_board() {
  local board="$1" backup_file="$2"

  log_info "Processing: $board"

  local recovery_info url hash
  if ! recovery_info=$(get_board_recovery_info "$board"); then
    return 1
  fi

  url="${recovery_info%%|*}"
  hash="${recovery_info#*|}"

  if [[ -z "$url" ]]; then
    log_error "Missing URL for $board"
    return 1
  fi

  if [[ -z "$hash" || "$hash" == "null" ]]; then
    if ! hash=$(compute_sri_hash "$url" "$board"); then
      return 1
    fi
  else
    hash=$(normalize_hash "$hash")
  fi

  log_verbose "$board url=$url hash=$hash"

  if ! update_sources_file "$board" "$url" "$hash"; then
    log_error "Update failed for $board"
    [[ -n "$backup_file" ]] && restore_backup "$backup_file"
    return 1
  fi
}

main() {
  parse_arguments "$@"
  trap cleanup EXIT

  local backup_file=""
  [[ "$DRY_RUN" != true ]] && backup_file=$(backup_sources)

  if ! fetch_releases_data; then
    exit 1
  fi

  local boards=()
  if [[ -n "$SPECIFIC_BOARD" ]]; then
    boards=("$SPECIFIC_BOARD")
  else
    boards=("${SUPPORTED_BOARDS[@]}")
  fi

  local success=0 total=${#boards[@]}
  for board in "${boards[@]}"; do
    process_board "$board" "$backup_file" && ((success++)) || true
  done

  if ! validate_sources_file; then
    [[ -n "$backup_file" ]] && restore_backup "$backup_file"
    exit 1
  fi

  if [[ "$DRY_RUN" == true ]]; then
    log_info "[DRY RUN] $total board(s) evaluated"
  else
    log_success "$success/$total boards updated"
    [[ $success -lt $total ]] && log_warn "Some boards failed"
  fi
}

main "$@"
