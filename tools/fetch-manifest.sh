#!/usr/bin/env bash

# Fetch Manifest Script
#
# Purpose: Download and process ChromeOS recovery image manifests for supported boards
# Dependencies: curl, jq, nix, unzip, sort
# Related: fetch-recovery.sh, manifests/*.nix
#
# This script fetches manifest JSON from ChromeOS CDN, downloads chunks in parallel,
# assembles the recovery image, extracts shim.bin, and generates Nix manifest files.
#
# Usage:
#   ./tools/fetch-manifest.sh dedede --jobs 4

set -euo pipefail

# Colors & Logging
ANSI_CLEAR='\033[0m'
ANSI_BOLD='\033[1m'
ANSI_GREEN='\033[1;32m'
ANSI_BLUE='\033[1;34m'
ANSI_YELLOW='\033[1;33m'
ANSI_RED='\033[1;31m'

log_info() { printf "${ANSI_BLUE}[INFO]${ANSI_CLEAR} %s\n" "$*" >&2; }
log_success() { printf "${ANSI_GREEN}[SUCCESS]${ANSI_CLEAR} %s\n" "$*" >&2; }
log_warn() { printf "${ANSI_YELLOW}[WARN]${ANSI_CLEAR} %s\n" "$*" >&2; }
log_error() { printf "${ANSI_RED}[ERROR]${ANSI_CLEAR} %s\n" "$*" >&2; }

# Defaults
PARALLEL_JOBS=2
OUT_PATH=""
REGENERATE=false
FIXUP=false

usage() {
	echo "Usage: $0 <board> [--jobs N] [--path FILE] [--regenerate] [--fixup]" >&2
	exit 1
}

BOARD=""
while [[ $# -gt 0 ]]; do
	case "$1" in
	--jobs)
		PARALLEL_JOBS="$2"
		shift 2
		;;
	--path)
		OUT_PATH="$2"
		shift 2
		;;
	--regenerate)
		REGENERATE=true
		shift
		;;
	--fixup)
		FIXUP=true
		shift
		;;
	-*)
		usage
		;;
	*)
		if [ -z "$BOARD" ]; then
			BOARD="$1"
		else
			usage
		fi
		shift
		;;
	esac
done

if [ -z "$BOARD" ]; then
	usage
fi

if [ -z "$OUT_PATH" ]; then
	OUT_PATH="manifests/${BOARD}-manifest.nix"
fi

# Ensure manifests directory exists
mkdir -p manifests

# --fixup mode: sort and clean manifest
if $FIXUP; then
	if [ ! -f "$OUT_PATH" ]; then
		log_error "Manifest file $OUT_PATH not found" >&2
		exit 1
	fi
	log_info "Fixing up manifest $OUT_PATH..." >&2
	header=$(sed -n '1,/chunks = \[/p' "$OUT_PATH")
	entries=$(grep '^[[:space:]]*{ name = "' "$OUT_PATH" | sort -t. -k3,3n)
	{
		echo "$header"
		echo "$entries"
		echo "  ];"
		echo "}"
	} >"${OUT_PATH}.fixed"
	mv "${OUT_PATH}.fixed" "$OUT_PATH"
	log_success "Manifest fixup complete: $OUT_PATH" >&2
	exit 0
fi

BASE_URL="https://cdn.cros.download/files/${BOARD}"
MANIFEST_URL="${BASE_URL}/${BOARD}.zip.manifest"

RETRY_COUNT="${RETRY_COUNT:-5}"
TIMEOUT_SECS="${TIMEOUT_SECS:-60}"
SLEEP_BETWEEN="${SLEEP_BETWEEN:-2}"

# Fetch manifest JSON
log_info "Fetching manifest for $BOARD..." >&2
manifest=$(curl -s --fail --connect-timeout 10 "$MANIFEST_URL")
zip_hash=$(echo "$manifest" | jq -r '.hash')
chunks=($(echo "$manifest" | jq -r '.chunks[]'))

# Resume / overwrite detection
start_index=0
if [ -f "$OUT_PATH" ]; then
	cp "$OUT_PATH" "$OUT_PATH.bak"
	log_info "Found existing manifest at $OUT_PATH (backup saved to $OUT_PATH.bak)" >&2

	existing_count=$(grep -c 'name = "' "$OUT_PATH" || true)
	total_count=${#chunks[@]}

	if [ "$existing_count" -ge "$total_count" ] && ! $REGENERATE; then
		log_success "Manifest already complete ($existing_count / $total_count chunks)" >&2
		exit 0
	fi

	last_done=$(grep -oE 'name = "[^"]+"' "$OUT_PATH" | tail -n1 | cut -d'"' -f2)
	if [ -n "$last_done" ] && ! $REGENERATE; then
		for i in "${!chunks[@]}"; do
			if [[ "${chunks[$i]}" == "$last_done" ]]; then
				start_index=$((i + 1))
				break
			fi
		done
		read -rp "Do you want to resume from chunk index $start_index (${chunks[$start_index]})? [Y/n] " ans
		if [[ "$ans" =~ ^[Nn]$ ]]; then
			start_index=0
			rm -f "${BOARD}".zip.* 2>/dev/null || true
			rm -f "$OUT_PATH"
		else
			for ((i = start_index; i < ${#chunks[@]}; i++)); do
				rm -f "${chunks[$i]}" 2>/dev/null || true
			done
		fi
	else
		start_index=0
		rm -f "${BOARD}".zip.* 2>/dev/null || true
		rm -f "$OUT_PATH"
	fi
fi

# Write header if starting fresh
if [ "$start_index" -eq 0 ]; then
	{
		echo "{"
		echo "  name = \"${BOARD}.zip\";"
		# We'll fill in the correct shim.bin hash later
		echo "  hash = \"\";"
		echo "  chunks = ["
	} >"$OUT_PATH"
fi

export BASE_URL RETRY_COUNT TIMEOUT_SECS SLEEP_BETWEEN OUT_PATH

# Function to download and hash a chunk
download_chunk() {
	idx="$1"
	chunk="$2"
	url="$BASE_URL/$chunk"

	for attempt in $(seq 1 "$RETRY_COUNT"); do
		log_info "[${idx}] Downloading $chunk (attempt $attempt/$RETRY_COUNT)..." >&2
		if curl -s --fail --connect-timeout "$TIMEOUT_SECS" --max-time "$TIMEOUT_SECS" \
			--progress-bar -o "$chunk" "$url" >&2; then
			break
		else
			log_warn "[${idx}] Failed to download $chunk, retrying..." >&2
			sleep 2
		fi
	done
	sleep "$SLEEP_BETWEEN"

	nix_hash=$(nix hash file --type sha256 "$chunk")
	echo "    { name = \"$chunk\"; sha256 = \"$nix_hash\"; }" >>"$OUT_PATH"
}

export -f download_chunk

# Start parallel downloads
printf "%s\n" "${chunks[@]:$start_index}" | nl -v"$start_index" -w4 -s' ' |
	xargs -n2 -P"$PARALLEL_JOBS" bash -c 'download_chunk "$@"' _

# Join chunks into a zip
cat "${BOARD}".zip.* >"${BOARD}.zip"

# Extract shim.bin from the zip
unzip -p "${BOARD}.zip" >"${BOARD}.bin"

# Compute Nix-style sha256 of shim.bin
shim_hash=$(nix hash file --type sha256 "${BOARD}.bin")

# Clean up temp files
rm -f "${BOARD}.zip" "${BOARD}.bin" "${BOARD}".zip.* 2>/dev/null || true

# Fix-up sort at the end and insert correct hash
log_info "Sorting manifest entries..." >&2
header=$(sed -n '1,/chunks = \[/p' "$OUT_PATH" | sed "s|hash = \"\";|hash = \"${shim_hash}\";|")
entries=$(grep '^[[:space:]]*{ name = "' "$OUT_PATH" | sort -t. -k3,3n)

{
	echo "$header"
	echo "$entries"
	echo "  ];"
	echo "}"
} >"${OUT_PATH}.sorted"

mv "${OUT_PATH}.sorted" "$OUT_PATH"

log_success "Manifest written to $OUT_PATH with shim.bin hash: $shim_hash" >&2
