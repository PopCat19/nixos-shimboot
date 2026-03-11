#!/usr/bin/env bash

# fetch-manifest.sh
#
# Purpose: Download ChromeOS recovery image chunks and generate a Nix manifest
#
# This module:
# - Fetches chunk manifest JSON from ChromeOS CDN
# - Downloads chunks with retry and optional parallelism
# - Assembles zip, extracts shim.bin, computes SRI hashes
# - Writes a sorted Nix manifest file

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/logging.sh"

PARALLEL_JOBS=2
OUT_PATH=""
REGENERATE=false
FIXUP=false
RETRY_COUNT="${RETRY_COUNT:-5}"
TIMEOUT_SECS="${TIMEOUT_SECS:-60}"
SLEEP_BETWEEN="${SLEEP_BETWEEN:-2}"

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
	-*) usage ;;
	*)
		[[ -z "$BOARD" ]] && BOARD="$1" || usage
		shift
		;;
	esac
done

[[ -z "$BOARD" ]] && usage

[[ -z "$OUT_PATH" ]] && OUT_PATH="manifests/${BOARD}-manifest.nix"
mkdir -p manifests

WORK_DIR="$(mktemp -d)"

cleanup() {
	rm -rf "$WORK_DIR"
}
trap cleanup EXIT

# --fixup mode: sort and clean existing manifest
if $FIXUP; then
	[[ ! -f "$OUT_PATH" ]] && {
		log_error "Manifest not found: $OUT_PATH"
		exit 1
	}

	log_info "Fixing up $OUT_PATH..."
	local_header=$(sed -n '1,/chunks = \[/p' "$OUT_PATH")
	local_entries=$(grep '^[[:space:]]*{ name = "' "$OUT_PATH" | sort -t'"' -k2 -V)

	{
		echo "$local_header"
		echo "$local_entries"
		echo "  ];"
		echo "}"
	} >"$OUT_PATH"

	log_success "Fixup complete: $OUT_PATH"
	exit 0
fi

BASE_URL="https://cdn.cros.download/files/${BOARD}"
MANIFEST_URL="${BASE_URL}/${BOARD}.zip.manifest"

log_info "Fetching manifest for $BOARD..."
manifest_json=$(curl -fsS --connect-timeout 10 "$MANIFEST_URL")
zip_hash=$(echo "$manifest_json" | jq -r '.hash')

mapfile -t chunks < <(echo "$manifest_json" | jq -r '.chunks[]')

if [[ ${#chunks[@]} -eq 0 ]]; then
	log_error "No chunks in manifest for $BOARD"
	exit 1
fi

total_chunks=${#chunks[@]}

# Resume detection
start_index=0
if [[ -f "$OUT_PATH" ]] && ! $REGENERATE; then
	cp "$OUT_PATH" "$OUT_PATH.bak"
	log_info "Existing manifest found (backup: $OUT_PATH.bak)"

	existing_count=$(grep -c 'name = "' "$OUT_PATH" 2>/dev/null || echo 0)

	if [[ "$existing_count" -ge "$total_chunks" ]]; then
		log_success "Manifest already complete ($existing_count/$total_chunks chunks)"
		exit 0
	fi

	last_done=$(grep -oP 'name = "\K[^"]+' "$OUT_PATH" | tail -1)
	if [[ -n "$last_done" ]]; then
		for i in "${!chunks[@]}"; do
			if [[ "${chunks[$i]}" == "$last_done" ]]; then
				start_index=$((i + 1))
				break
			fi
		done

		if [[ -t 0 ]]; then
			read -rp "Resume from chunk $start_index/${total_chunks} (${chunks[$start_index]:-done})? [Y/n] " ans
		else
			ans="Y"
		fi

		if [[ "$ans" =~ ^[Nn]$ ]]; then
			start_index=0
		fi
	fi
fi

if [[ "$start_index" -eq 0 ]]; then
	rm -f "$OUT_PATH"
fi

# Download a single chunk, write hash entry to a per-chunk temp file
download_chunk() {
	local idx="$1" chunk="$2" work_dir="$3" base_url="$4"
	local retry_count="${RETRY_COUNT:-5}" timeout="${TIMEOUT_SECS:-60}"
	local url="${base_url}/${chunk}"
	local chunk_file="${work_dir}/${chunk}"
	local hash_file="${work_dir}/${chunk}.hash"

	for attempt in $(seq 1 "$retry_count"); do
		log_info "[$idx] $chunk (attempt $attempt/$retry_count)"
		if curl -fsL --connect-timeout "$timeout" --max-time "$timeout" \
			-o "$chunk_file" "$url"; then
			break
		fi
		log_warn "[$idx] Retry $chunk..."
		sleep "${SLEEP_BETWEEN:-2}"
	done

	if [[ ! -f "$chunk_file" ]]; then
		log_error "[$idx] Failed to download $chunk after $retry_count attempts"
		return 1
	fi

	local nix_hash
	nix_hash=$(nix hash file --type sha256 "$chunk_file")
	echo "    { name = \"$chunk\"; sha256 = \"$nix_hash\"; }" >"$hash_file"
}

export -f download_chunk log_info log_warn log_error
export RETRY_COUNT TIMEOUT_SECS SLEEP_BETWEEN

log_info "Downloading ${total_chunks} chunks ($start_index already done)..."

remaining_chunks=("${chunks[@]:$start_index}")

printf "%s\n" "${remaining_chunks[@]}" |
	nl -v"$start_index" -w4 -s' ' |
	xargs -n2 -P"$PARALLEL_JOBS" bash -c 'download_chunk "$1" "$2" "$3" "$4"' _ \
		{} {} "$WORK_DIR" "$BASE_URL"

# Verify all chunk hash files exist
missing=0
for chunk in "${chunks[@]}"; do
	if [[ ! -f "$WORK_DIR/${chunk}.hash" ]]; then
		# Check if it was from a previous run (already in manifest)
		if [[ "$start_index" -gt 0 ]] && grep -q "\"$chunk\"" "$OUT_PATH" 2>/dev/null; then
			continue
		fi
		log_error "Missing hash for chunk: $chunk"
		((missing++))
	fi
done

if [[ "$missing" -gt 0 ]]; then
	log_error "$missing chunk(s) failed to download"
	exit 1
fi

# Assemble zip from chunks in correct numerical order
log_info "Assembling zip from chunks..."
zip_file="$WORK_DIR/${BOARD}.zip"

for chunk in "${chunks[@]}"; do
	cat "$WORK_DIR/$chunk" >>"$zip_file"
done

# Extract shim.bin and compute hash
shim_file="$WORK_DIR/${BOARD}.bin"
if ! unzip -p "$zip_file" "shim.bin" >"$shim_file" 2>/dev/null; then
	log_error "Failed to extract shim.bin from assembled zip"
	exit 1
fi

shim_hash=$(nix hash file --type sha256 "$shim_file")
log_info "shim.bin hash: $shim_hash"

# Assemble sorted manifest
# Collect entries: existing (from resume) + new
{
	echo "{"
	echo "  name = \"${BOARD}.zip\";"
	echo "  hash = \"${shim_hash}\";"
	echo "  chunks = ["

	# Existing entries from resumed manifest
	if [[ -f "$OUT_PATH" ]]; then
		grep '^[[:space:]]*{ name = "' "$OUT_PATH" 2>/dev/null || true
	fi

	# New entries from this run, in chunk order
	for chunk in "${remaining_chunks[@]}"; do
		[[ -f "$WORK_DIR/${chunk}.hash" ]] && cat "$WORK_DIR/${chunk}.hash"
	done

	echo "  ];"
	echo "}"
} >"$WORK_DIR/manifest-unsorted.nix"

# Sort chunk entries for determinism
header=$(sed -n '1,/chunks = \[/p' "$WORK_DIR/manifest-unsorted.nix")
entries=$(grep '^[[:space:]]*{ name = "' "$WORK_DIR/manifest-unsorted.nix" | sort -t'"' -k2 -V)

{
	echo "$header"
	echo "$entries"
	echo "  ];"
	echo "}"
} >"$OUT_PATH"

log_success "Manifest written: $OUT_PATH"
