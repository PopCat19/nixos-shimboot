#!/usr/bin/env bash
set -euo pipefail

# fetch-recovery.sh
# Automate fetching ChromeOS recovery image hashes for all supported boards
# Uses ChromeOS Releases JSON API and updates chromeos-sources.nix

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
	"dedede"
	"octopus"
	"zork"
	"nissa"
	"hatch"
	"corsola"
	"grunt"
	"jacuzzi"
	"hana"
	"snappy"
)

# Global variables
DRY_RUN=false
VERBOSE=false
SPECIFIC_BOARD=""
TEMP_JSON_FILE=""

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
	echo -e "${BLUE}[INFO]${NC} $*" >&2
}

log_warn() {
	echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
	echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_success() {
	echo -e "${GREEN}[SUCCESS]${NC} $*" >&2
}

# Usage information
usage() {
	cat << EOF
Usage: $0 [OPTIONS] [BOARD]

Automate fetching ChromeOS recovery image hashes for all supported boards
using the ChromeOS Releases JSON API and update chromeos-sources.nix.

OPTIONS:
    -h, --help      Show this help message
    -d, --dry-run   Show what would be changed without making modifications
    -v, --verbose   Enable verbose output
    -b, --board     Process only specific board (instead of all)

BOARDS:
    ${SUPPORTED_BOARDS[*]}

EXAMPLES:
    $0                          # Process all boards
    $0 --dry-run               # Show what would change
    $0 --board corsola         # Process only corsola board
    $0 -dv                     # Dry run with verbose output

EOF
}

# Parse command line arguments
parse_arguments() {
	while [[ $# -gt 0 ]]; do
		case $1 in
			-h|--help)
				usage
				exit 0
				;;
			-d|--dry-run)
				DRY_RUN=true
				shift
				;;
			-v|--verbose)
				VERBOSE=true
				shift
				;;
			-b|--board)
				SPECIFIC_BOARD="$2"
				if [[ ! " ${SUPPORTED_BOARDS[*]} " =~ " $SPECIFIC_BOARD " ]]; then
					log_error "Unsupported board: $SPECIFIC_BOARD"
					log_error "Supported boards: ${SUPPORTED_BOARDS[*]}"
					exit 1
				fi
				shift 2
				;;
			*)
				log_error "Unknown option: $1"
				usage
				exit 1
				;;
		esac
	done
}

# Setup temporary directories and files
setup_environment() {
	mkdir -p "$BACKUP_DIR"
	mkdir -p "$TEMP_DIR"
	
	# Create temporary file for JSON data
	TEMP_JSON_FILE=$(mktemp "$TEMP_DIR/chromeos-releases-XXXXXX.json")
	
	if [[ "$VERBOSE" == true ]]; then
		log_info "Created temporary files in $TEMP_DIR"
	fi
}

# Cleanup temporary files
cleanup() {
	if [[ -n "$TEMP_JSON_FILE" && -f "$TEMP_JSON_FILE" ]]; then
		rm -f "$TEMP_JSON_FILE"
		if [[ "$VERBOSE" == true ]]; then
			log_info "Cleaned up temporary files"
		fi
	fi
}

# Backup chromeos-sources.nix
backup_nix_file() {
	local backup_file="$BACKUP_DIR/chromeos-sources.nix.backup.$(date +%Y%m%d_%H%M%S)"
	cp "$CHROMEOS_SOURCES_FILE" "$backup_file"
	log_info "Backed up chromeos-sources.nix to $backup_file"
	echo "$backup_file"
}

# Restore backup file
restore_backup() {
	local backup_file="$1"
	if [[ -f "$backup_file" ]]; then
		cp "$backup_file" "$CHROMEOS_SOURCES_FILE"
		log_info "Restored backup from $backup_file"
	else
		log_error "Backup file not found: $backup_file"
	fi
}

# Download ChromeOS releases JSON data
fetch_chromeos_releases_data() {
	log_info "Downloading ChromeOS releases data from JSON API..."
	log_info "URL: $CHROMEOS_RELEASES_URL"
	
	if ! curl --fail --connect-timeout 10 --max-time 30 --progress-bar -L "$CHROMEOS_RELEASES_URL" -o "$TEMP_JSON_FILE"; then
		log_warn "Failed to download from ChromeOS releases API, trying fallback..."
		return 1
	fi
	
	# Validate JSON
	if ! jq empty "$TEMP_JSON_FILE" 2>/dev/null; then
		log_error "Downloaded data is not valid JSON"
		return 1
	fi
	
	local board_count=$(jq -r 'keys | length' "$TEMP_JSON_FILE" 2>/dev/null || echo "unknown")
	log_info "Successfully downloaded JSON data with $board_count boards"
	
	return 0
}

# Fallback to Google's recovery2.json API
fetch_google_recovery_data() {
	log_info "Using fallback Google recovery API..."
	
	local temp_google_file=$(mktemp "$TEMP_DIR/google-recovery-XXXXXX.json")
	
	if ! curl -s --fail --connect-timeout 10 --max-time 30 "$GOOGLE_RECOVERY_API" -o "$temp_google_file"; then
		log_error "Failed to download from Google recovery API"
		rm -f "$temp_google_file"
		return 1
	fi
	
	# Convert Google API format to our expected format
	jq -r 'map({
		(.board): {
			recovery: {
				stable: {
					url: .url,
					sha256: .sha256,
					version: .version
				}
			}
		}
	}) | add' "$temp_google_file" > "$TEMP_JSON_FILE"
	
	rm -f "$temp_google_file"
	
	if [[ "$VERBOSE" == true ]]; then
		log_info "Successfully converted Google API data to JSON format"
	fi
	
	return 0
}

# Get board recovery information from JSON
get_board_recovery_info() {
	local board="$1"
	local url=""
	local hash=""
	
	# Try to extract from ChromeOS releases JSON first
	if [[ -f "$TEMP_JSON_FILE" ]]; then
		# Extract the latest stable-channel image for the board using jq properly
		url=$(jq -r ".\"$board\".images[] | select(.channel == \"stable-channel\") | .url" "$TEMP_JSON_FILE" 2>/dev/null | head -1)
		
		if [[ "$VERBOSE" == true ]]; then
			log_info "Debug: Extracted URL from JSON: '$url'"
		fi
		
		# Note: The JSON doesn't include SHA256, so we'll need to compute it
	fi
	
	# If not found or no URL, try Google API as fallback
	if [[ -z "$url" || "$url" == "null" || "$url" == "empty" ]]; then
		log_warn "Board $board not found in ChromeOS releases JSON, trying Google API..."
		
		# Use jq to properly filter and get the first result
		url=$(curl -s "$GOOGLE_RECOVERY_API" | jq -r ".[] | select(.file | contains(\"$board\")) | select(.channel == \"STABLE\") | .url" 2>/dev/null | head -1)
		hash=$(curl -s "$GOOGLE_RECOVERY_API" | jq -r ".[] | select(.file | contains(\"$board\")) | select(.channel == \"STABLE\") | .sha256" 2>/dev/null | head -1)
		
		if [[ "$VERBOSE" == true ]]; then
			log_info "Debug: Extracted URL from Google API: '$url'"
			log_info "Debug: Extracted hash from Google API: '$hash'"
		fi
	fi
	
	if [[ -z "$url" || "$url" == "null" || "$url" == "empty" ]]; then
		log_error "No recovery data found for board: $board"
		return 1
	fi
	
	echo "$url|$hash"
	return 0
}

# Verify recovery hash (optional download verification)
verify_recovery_hash() {
	local url="$1"
	local expected_hash="$2"
	local board="$3"
	local temp_file="$TEMP_DIR/${board}-recovery-verification.zip"
	
	log_info "Verifying hash for $board (this may take a while)..."
	
	if ! curl -s --fail --connect-timeout 10 --max-time 300 "$url" -o "$temp_file"; then
		log_warn "Failed to download recovery image for verification"
		return 1
	fi
	
	local computed_hash=$(nix hash file --type sha256 "$temp_file" 2>/dev/null || echo "")
	rm -f "$temp_file"
	
	if [[ -z "$computed_hash" ]]; then
		log_warn "Failed to compute hash for verification"
		return 1
	fi
	
	if [[ "$computed_hash" == "$expected_hash" ]]; then
		log_success "Hash verification passed for $board"
		return 0
	else
		log_warn "Hash verification failed for $board"
		log_warn "Expected: $expected_hash"
		log_warn "Computed: $computed_hash"
		return 1
	fi
}

# Update chromeos-sources.nix with new URL and hash
update_nix_recovery_urls() {
	local board="$1"
	local url="$2"
	local hash="$3"
	
	log_info "Updating chromeos-sources.nix for board: $board"
	
	if [[ "$DRY_RUN" == true ]]; then
		log_info "[DRY RUN] Would update $board with:"
		log_info "[DRY RUN]   URL: $url"
		log_info "[DRY RUN]   Hash: $hash"
		return 0
	fi
	
	# Create a temporary file for the updated content
	local temp_nix_file=$(mktemp "$TEMP_DIR/chromeos-sources-updated-XXXXXX.nix")
	
	# Update the URL for the board
	sed "/$board = {/,/}/ {
		s|url = \".*\";|url = \"$url\";|
	}" "$CHROMEOS_SOURCES_FILE" > "$temp_nix_file"
	
	# Update the hash for the board
	sed "/$board = {/,/}/ {
		s|sha256 = \".*\";|sha256 = \"$hash\";|
	}" "$temp_nix_file" > "${temp_nix_file}.new"
	mv "${temp_nix_file}.new" "$temp_nix_file"
	
	# Replace the original file
	mv "$temp_nix_file" "$CHROMEOS_SOURCES_FILE"
	
	log_success "Updated $board in chromeos-sources.nix"
}

# Validate nix file syntax
validate_nix_file() {
	if [[ "$DRY_RUN" == true ]]; then
		log_info "[DRY RUN] Would validate nix file syntax"
		return 0
	fi
	
	log_info "Validating nix file syntax..."
	
	if ! nix-instantiate --parse "$CHROMEOS_SOURCES_FILE" >/dev/null 2>&1; then
		log_error "Nix file syntax validation failed"
		return 1
	fi
	
	if ! nix flake check --no-build 2>/dev/null; then
		log_warn "Flake check failed, but syntax is valid"
	fi
	
	log_success "Nix file syntax validation passed"
	return 0
}

# Process a single board
process_board() {
	local board="$1"
	local backup_file="$2"
	
	log_info "Processing board: $board"
	
	# Get recovery information
	local recovery_info
	if ! recovery_info=$(get_board_recovery_info "$board"); then
		log_error "Failed to get recovery info for board: $board"
		return 1
	fi
	
	local url=$(echo "$recovery_info" | cut -d'|' -f1)
	local hash=$(echo "$recovery_info" | cut -d'|' -f2)
	
	if [[ -z "$url" ]]; then
		log_error "Missing URL for board: $board"
		return 1
	fi
	
	# If hash is missing, compute it from the URL
	if [[ -z "$hash" || "$hash" == "null" || "$hash" == "empty" ]]; then
		log_info "Computing hash for $board (this may take a while)..."
		local temp_file="$TEMP_DIR/${board}-recovery-hash.zip"
		
		log_info "Downloading recovery image from: $url"
		if curl --fail --connect-timeout 10 --max-time 300 --progress-bar -L "$url" -o "$temp_file"; then
			log_info "Download completed, computing SHA256 hash..."
			hash=$(nix hash file --type sha256 "$temp_file" 2>/dev/null || echo "")
			rm -f "$temp_file"
		else
			log_error "Failed to download recovery image for hash computation"
			rm -f "$temp_file"
		fi
	fi
	
	# Ensure hash has proper format
	if [[ -n "$hash" && ! "$hash" =~ ^sha256- ]]; then
		hash="sha256-$hash"
	fi
	
	if [[ -z "$hash" || "$hash" == "null" || "$hash" == "empty" ]]; then
		log_error "Missing hash for board: $board"
		return 1
	fi
	
	if [[ "$VERBOSE" == true ]]; then
		log_info "Found recovery data for $board:"
		log_info "  URL: $url"
		log_info "  Hash: $hash"
	fi
	
	# Optional hash verification (disabled by default for performance)
	# if [[ "$VERBOSE" == true ]]; then
	# 	verify_recovery_hash "$url" "$hash" "$board"
	# fi
	
	# Update nix file
	if ! update_nix_recovery_urls "$board" "$url" "$hash"; then
		log_error "Failed to update nix file for board: $board"
		restore_backup "$backup_file"
		return 1
	fi
	
	log_success "Successfully processed board: $board"
	return 0
}

# Main processing function
main() {
	local backup_file=""
	
	# Parse arguments
	parse_arguments "$@"
	
	# Setup environment
	setup_environment
	trap cleanup EXIT
	
	# Create backup
	if [[ "$DRY_RUN" != true ]]; then
		backup_file=$(backup_nix_file)
	fi
	
	# Download ChromeOS releases data
	if ! fetch_chromeos_releases_data; then
		if ! fetch_google_recovery_data; then
			log_error "Failed to fetch recovery data from all sources"
			exit 1
		fi
	fi
	
	# Determine which boards to process
	local boards_to_process=()
	if [[ -n "$SPECIFIC_BOARD" ]]; then
		boards_to_process=("$SPECIFIC_BOARD")
	else
		boards_to_process=("${SUPPORTED_BOARDS[@]}")
	fi
	
	# Process each board
	local success_count=0
	local total_count=${#boards_to_process[@]}
	
	for board in "${boards_to_process[@]}"; do
		if process_board "$board" "$backup_file"; then
			((success_count++))
		fi
	done
	
	# Validate final nix file
	if [[ "$DRY_RUN" != true ]]; then
		if ! validate_nix_file; then
			log_error "Final nix file validation failed"
			restore_backup "$backup_file"
			exit 1
		fi
	fi
	
	# Report results
	if [[ "$DRY_RUN" == true ]]; then
		log_info "[DRY RUN] Would have processed $total_count boards"
	else
		log_success "Successfully processed $success_count/$total_count boards"
		
		if [[ $success_count -eq $total_count ]]; then
			log_success "All boards processed successfully!"
		else
			log_warn "Some boards failed to process. Check logs above."
		fi
	fi
}

# Run main function with all arguments
main "$@"