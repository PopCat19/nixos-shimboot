#!/usr/bin/env bash
set -euo pipefail

# fetch-recovery.sh
# Automate fetching ChromeOS recovery image hashes for all supported boards

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly CHROMEOS_SOURCES_FILE="$PROJECT_ROOT/flake_modules/chromeos-sources.nix"
readonly BACKUP_DIR="$PROJECT_ROOT/.backup"
readonly TEMP_DIR="$PROJECT_ROOT/.temp"

# ChromeOS Releases JSON API
readonly CHROMEOS_RELEASES_URL="https://cdn.jsdelivr.net/gh/MercuryWorkshop/chromeos-releases-data/data.json"
readonly GOOGLE_RECOVERY_API="https://dl.google.com/dl/edgedl/chromeos/recovery/recovery2.json"

# Supported boards from flake.nix
readonly SUPPORTED_BOARDS=(
	"dedede" "octopus" "zork" "nissa" "hatch"
	"grunt" "snappy"
)

# Global variables
DRY_RUN=false
VERBOSE=false
SPECIFIC_BOARD=""
TEMP_JSON_FILE=""

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Logging
log_info() { echo -e "${BLUE}[INFO]${NC} $*" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*" >&2; }

usage() {
	cat << 'EOF'
Usage: $0 [OPTIONS] [BOARD]

Fetch ChromeOS recovery image hashes and update chromeos-sources.nix.

OPTIONS:
    -h, --help      Show this help message
    -d, --dry-run   Show changes without modifying files
    -v, --verbose   Enable verbose output
    -b, --board     Process only specific board

EXAMPLES:
    $0                     # Process all boards
    $0 --dry-run          # Show what would change
    $0 --board corsola    # Process only corsola
EOF
}

parse_arguments() {
	while [[ $# -gt 0 ]]; do
		case $1 in
			-h|--help) usage; exit 0 ;;
			-d|--dry-run) DRY_RUN=true; shift ;;
			-v|--verbose) VERBOSE=true; shift ;;
			-b|--board)
				SPECIFIC_BOARD="$2"
				if [[ ! " ${SUPPORTED_BOARDS[*]} " =~ " $SPECIFIC_BOARD " ]]; then
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

setup_environment() {
	mkdir -p "$BACKUP_DIR" "$TEMP_DIR"
	TEMP_JSON_FILE=$(mktemp "$TEMP_DIR/chromeos-releases-XXXXXX.json")
	[[ "$VERBOSE" == true ]] && log_info "Temp files in $TEMP_DIR"
}

cleanup() {
	[[ -n "$TEMP_JSON_FILE" && -f "$TEMP_JSON_FILE" ]] && rm -f "$TEMP_JSON_FILE"
	[[ "$VERBOSE" == true ]] && log_info "Cleaned up temporary files"
}

backup_nix_file() {
	local backup_file="$BACKUP_DIR/chromeos-sources.nix.backup.$(date +%Y%m%d_%H%M%S)"
	cp "$CHROMEOS_SOURCES_FILE" "$backup_file"
	log_info "Backed up to $backup_file"
	echo "$backup_file"
}

restore_backup() {
	local backup_file="$1"
	if [[ -f "$backup_file" ]]; then
		cp "$backup_file" "$CHROMEOS_SOURCES_FILE"
		log_info "Restored backup from $backup_file"
	fi
}

fetch_chromeos_releases_data() {
	log_info "Downloading ChromeOS releases data..."
	
	if ! curl --fail --connect-timeout 10 --max-time 30 --progress-bar \
		-L "$CHROMEOS_RELEASES_URL" -o "$TEMP_JSON_FILE" 2>&1; then
		log_warn "Failed to download from ChromeOS releases API"
		return 1
	fi
	
	if ! jq empty "$TEMP_JSON_FILE" 2>/dev/null; then
		log_error "Downloaded data is not valid JSON"
		return 1
	fi
	
	local board_count=$(jq -r 'keys | length' "$TEMP_JSON_FILE" 2>/dev/null || echo "0")
	log_info "Downloaded data for $board_count boards"
	return 0
}

fetch_google_recovery_data() {
	log_info "Using fallback Google recovery API..."
	
	local temp_google=$(mktemp "$TEMP_DIR/google-recovery-XXXXXX.json")
	
	if ! curl -s --fail --connect-timeout 10 --max-time 30 \
		"$GOOGLE_RECOVERY_API" -o "$temp_google"; then
		log_error "Failed to download from Google recovery API"
		rm -f "$temp_google"
		return 1
	fi
	
	# Convert to expected format
	jq 'reduce .[] as $item ({}; 
		if $item.channel == "stable-channel" then
			.[$item.board] = {url: $item.url, sha256: $item.sha256}
		else . end
	)' "$temp_google" > "$TEMP_JSON_FILE"
	
	rm -f "$temp_google"
	[[ "$VERBOSE" == true ]] && log_info "Converted Google API data"
	return 0
}

get_board_recovery_info() {
	local board="$1"
	local url=""
	local hash=""
	
	# Try ChromeOS releases JSON
	if [[ -f "$TEMP_JSON_FILE" ]]; then
		url=$(jq -r --arg board "$board" \
			'.[$board].images[]? | select(.channel == "stable-channel") | .url' \
			"$TEMP_JSON_FILE" 2>/dev/null | head -1)
	fi
	
	# Fallback to Google API
	if [[ -z "$url" || "$url" == "null" ]]; then
		log_warn "Board $board not in JSON, trying Google API..."
		local google_data=$(curl -s "$GOOGLE_RECOVERY_API")
		url=$(echo "$google_data" | jq -r --arg board "$board" \
			'.[] | select(.file | contains($board)) | select(.channel == "stable-channel") | .url' \
			2>/dev/null | head -1)
		hash=$(echo "$google_data" | jq -r --arg board "$board" \
			'.[] | select(.file | contains($board)) | select(.channel == "stable-channel") | .sha256' \
			2>/dev/null | head -1)
	fi
	
	if [[ -z "$url" || "$url" == "null" ]]; then
		log_error "No recovery data for board: $board"
		return 1
	fi
	
	echo "$url|$hash"
}

compute_nix_hash() {
	local url="$1"
	local board="$2"
	local temp_file="$TEMP_DIR/${board}-recovery.bin"
	
	log_info "Computing hash for $board (downloading)..."
	
	if ! curl -L --fail --progress-bar "$url" -o "$temp_file"; then
		log_error "Failed to download recovery image"
		rm -f "$temp_file"
		return 1
	fi
	
	local nix_hash
	nix_hash=$(nix hash file --type sha256 "$temp_file" 2>/dev/null)
	rm -f "$temp_file"
	
	if [[ -z "$nix_hash" ]]; then
		log_error "Failed to compute hash"
		return 1
	fi
	
	echo "$nix_hash"
}

update_nix_file() {
	local board="$1"
	local url="$2"
	local hash="$3"
	
	log_info "Updating chromeos-sources.nix for $board"
	
	if [[ "$DRY_RUN" == true ]]; then
		log_info "[DRY RUN] Would update:"
		log_info "  Board: $board"
		log_info "  URL: $url"
		log_info "  Hash: $hash"
		return 0
	fi
	
	# Use awk for reliable multi-line pattern replacement
	awk -v board="$board" -v url="$url" -v hash="$hash" '
		BEGIN { in_board = 0 }
		$0 ~ board " = \\{" { in_board = 1 }
		in_board && /url = / { $0 = "        url = \"" url "\";" }
		in_board && /sha256 = / { $0 = "        sha256 = \"" hash "\";"; in_board = 0 }
		{ print }
	' "$CHROMEOS_SOURCES_FILE" > "${CHROMEOS_SOURCES_FILE}.tmp"
	
	mv "${CHROMEOS_SOURCES_FILE}.tmp" "$CHROMEOS_SOURCES_FILE"
	log_success "Updated $board"
}

validate_nix_file() {
	[[ "$DRY_RUN" == true ]] && return 0
	
	log_info "Validating nix file syntax..."
	
	if ! nix-instantiate --parse "$CHROMEOS_SOURCES_FILE" >/dev/null 2>&1; then
		log_error "Nix syntax validation failed"
		return 1
	fi
	
	log_success "Nix syntax valid"
	return 0
}

process_board() {
	local board="$1"
	local backup_file="$2"
	
	log_info "Processing board: $board"
	
	local recovery_info url hash
	if ! recovery_info=$(get_board_recovery_info "$board"); then
		log_error "Failed to get recovery info for $board"
		return 1
	fi
	
	url=$(echo "$recovery_info" | cut -d'|' -f1)
	hash=$(echo "$recovery_info" | cut -d'|' -f2)
	
	if [[ -z "$url" ]]; then
		log_error "Missing URL for $board"
		return 1
	fi
	
	# Compute hash if missing
	if [[ -z "$hash" || "$hash" == "null" ]]; then
		if ! hash=$(compute_nix_hash "$url" "$board"); then
			log_error "Failed to compute hash for $board"
			return 1
		fi
	fi
	
	# Ensure proper hash format
	if [[ "$hash" != sha256-* ]]; then
		hash="sha256-$hash"
	fi
	
	[[ "$VERBOSE" == true ]] && log_info "URL: $url" && log_info "Hash: $hash"
	
	if ! update_nix_file "$board" "$url" "$hash"; then
		log_error "Failed to update nix file for $board"
		restore_backup "$backup_file"
		return 1
	fi
	
	log_success "Successfully processed $board"
}

main() {
	parse_arguments "$@"
	setup_environment
	trap cleanup EXIT
	
	local backup_file=""
	[[ "$DRY_RUN" != true ]] && backup_file=$(backup_nix_file)
	
	if ! fetch_chromeos_releases_data; then
		if ! fetch_google_recovery_data; then
			log_error "Failed to fetch recovery data"
			exit 1
		fi
	fi
	
	local boards_to_process=()
	if [[ -n "$SPECIFIC_BOARD" ]]; then
		boards_to_process=("$SPECIFIC_BOARD")
	else
		boards_to_process=("${SUPPORTED_BOARDS[@]}")
	fi
	
	local success=0 total=${#boards_to_process[@]}
	for board in "${boards_to_process[@]}"; do
		process_board "$board" "$backup_file" && ((success++)) || true
	done
	
	if [[ "$DRY_RUN" != true ]]; then
		validate_nix_file || { restore_backup "$backup_file"; exit 1; }
	fi
	
	if [[ "$DRY_RUN" == true ]]; then
		log_info "[DRY RUN] Would process $total boards"
	else
		log_success "Processed $success/$total boards"
		[[ $success -eq $total ]] && log_success "All boards complete!" || log_warn "Some boards failed"
	fi
}

main "$@"