#!/usr/bin/env bash
set -euo pipefail

# Defaults
PARALLEL_JOBS=4
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
    OUT_PATH="${BOARD}-manifest.nix"
fi

# --fixup mode: just sort and clean manifest
if $FIXUP; then
    if [ ! -f "$OUT_PATH" ]; then
        echo "[!] Manifest file $OUT_PATH not found" >&2
        exit 1
    fi
    echo "[*] Fixing up manifest $OUT_PATH..." >&2

    # Grab header up to and including 'chunks = ['
    header=$(sed -n '1,/chunks = \[/p' "$OUT_PATH")

    # Grab only chunk entries (lines starting with spaces then '{ name =')
    entries=$(grep '^[[:space:]]*{ name = "' "$OUT_PATH" | sort -t. -k3,3n)

    # Grab footer from closing bracket onward
    footer=$(sed -n '/];/,$p' "$OUT_PATH")

    {
        echo "$header"
        echo "$entries"
        echo "  ];"
        echo "}"
    } > "${OUT_PATH}.fixed"

    mv "${OUT_PATH}.fixed" "$OUT_PATH"
    echo "[+] Manifest fixup complete: $OUT_PATH" >&2
    exit 0
fi

# Normal download/regenerate logic below...
BASE_URL="https://cdn.cros.download/files/${BOARD}"
MANIFEST_URL="${BASE_URL}/${BOARD}.zip.manifest"

RETRY_COUNT="${RETRY_COUNT:-5}"
TIMEOUT_SECS="${TIMEOUT_SECS:-60}"
SLEEP_BETWEEN="${SLEEP_BETWEEN:-0.2}"

# Fetch manifest JSON
echo "[*] Fetching manifest for $BOARD..." >&2
manifest=$(curl -s --fail --connect-timeout 10 "$MANIFEST_URL")
final_hash=$(echo "$manifest" | jq -r '.hash')
chunks=($(echo "$manifest" | jq -r '.chunks[]'))

# Resume / overwrite detection
start_index=0
if [ -f "$OUT_PATH" ]; then
    cp "$OUT_PATH" "$OUT_PATH.bak"
    echo "[*] Found existing manifest at $OUT_PATH (backup saved to $OUT_PATH.bak)" >&2

    existing_count=$(grep -c 'name = "' "$OUT_PATH" || true)
    total_count=${#chunks[@]}

    if [ "$existing_count" -ge "$total_count" ] && ! $REGENERATE; then
        echo "[+] Manifest already complete ($existing_count / $total_count chunks)" >&2
        exit 0
    fi

    last_done=$(grep -oE 'name = "[^"]+"' "$OUT_PATH" | tail -n1 | cut -d'"' -f2)
    if [ -n "$last_done" ] && ! $REGENERATE; then
        for i in "${!chunks[@]}"; do
            if [[ "${chunks[$i]}" == "$last_done" ]]; then
                start_index=$((i+1))
                break
            fi
        done
        read -rp "Do you want to resume from chunk index $start_index (${chunks[$start_index]})? [Y/n] " ans
        if [[ "$ans" =~ ^[Nn]$ ]]; then
            start_index=0
            rm -f ${BOARD}.zip.* 2>/dev/null || true
            rm -f "$OUT_PATH"
        else
            for ((i=start_index; i<${#chunks[@]}; i++)); do
                rm -f "${chunks[$i]}" 2>/dev/null || true
            done
        fi
    else
        start_index=0
        rm -f ${BOARD}.zip.* 2>/dev/null || true
        rm -f "$OUT_PATH"
    fi
fi

# Write header if starting fresh
if [ "$start_index" -eq 0 ]; then
    {
        echo "{"
        echo "  name = \"${BOARD}.zip\";"
        echo "  hash = \"${final_hash}\";"
        echo "  chunks = ["
    } > "$OUT_PATH"
fi

export BASE_URL RETRY_COUNT TIMEOUT_SECS SLEEP_BETWEEN OUT_PATH

# Function to download and hash a chunk
download_chunk() {
    idx="$1"
    chunk="$2"
    url="$BASE_URL/$chunk"

    for attempt in $(seq 1 "$RETRY_COUNT"); do
        echo "[${idx}] Downloading $chunk (attempt $attempt/$RETRY_COUNT)..." >&2
        if curl -s --fail --connect-timeout "$TIMEOUT_SECS" --max-time "$TIMEOUT_SECS" \
             --progress-bar -o "$chunk" "$url" >&2; then
          break
        else
          echo "[${idx}] Failed to download $chunk, retrying..." >&2
          sleep 2
        fi
    done
    sleep "$SLEEP_BETWEEN"

    nix_hash=$(nix hash file --type sha256 "$chunk")
    echo "    { name = \"$chunk\"; sha256 = \"$nix_hash\"; }" >> "$OUT_PATH"
    rm -f "$chunk"
}

export -f download_chunk

# Start parallel downloads
printf "%s\n" "${chunks[@]:$start_index}" | nl -v"$start_index" -w4 -s' ' | \
xargs -n2 -P"$PARALLEL_JOBS" bash -c 'download_chunk "$@"' _

# Fix-up sort at the end
echo "[*] Sorting manifest entries..." >&2
header=$(sed -n '1,/chunks = \[/p' "$OUT_PATH")
entries=$(grep '^[[:space:]]*{ name = "' "$OUT_PATH" | sort -t. -k3,3n)
footer=$(sed -n '/];/,$p' "$OUT_PATH")

{
    echo "$header"
    echo "$entries"
    echo "  ];"
    echo "}"
} > "${OUT_PATH}.sorted"

mv "${OUT_PATH}.sorted" "$OUT_PATH"

echo "[+] Manifest written to $OUT_PATH" >&2