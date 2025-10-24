#!/usr/bin/env bash
set -euo pipefail

# fetch-recovery.sh
# Fetch ChromeOS recovery image for a board and compute its sha256 hash.
# This is used to populate the sha256 field in chromeos-sources.nix

usage() {
	echo "Usage: $0 <board>" >&2
	exit 1
}

BOARD="${1:-}"
if [ -z "$BOARD" ]; then
	usage
fi

# ChromeOS recovery image URL format
# Based on: https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_16295.54.0_${board}_recovery_stable-channel_${board}MPKeys-v54.bin.zip
VERSION="16295.54.0"
CHANNEL="stable-channel"
MPVERSION="v54"

URL="https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_${VERSION}_${BOARD}_recovery_${CHANNEL}_${BOARD}MPKeys-${MPVERSION}.bin.zip"

echo "[*] Fetching recovery image for $BOARD..." >&2
echo "    URL: $URL" >&2

# Download with retry logic
RETRY_COUNT="${RETRY_COUNT:-5}"
TIMEOUT_SECS="${TIMEOUT_SECS:-300}"  # 5 minutes timeout for large files

for attempt in $(seq 1 "$RETRY_COUNT"); do
	echo "[*] Download attempt $attempt/$RETRY_COUNT..." >&2
	if curl -s --fail --connect-timeout 10 --max-time "$TIMEOUT_SECS" \
		--progress-bar -o "${BOARD}-recovery.zip" "$URL" >&2; then
		break
	else
		echo "[!] Failed to download, retrying..." >&2
		sleep 2
	fi
done

if [ ! -f "${BOARD}-recovery.zip" ]; then
	echo "[!] Failed to download recovery image after $RETRY_COUNT attempts" >&2
	exit 1
fi

# Compute sha256 hash
echo "[*] Computing sha256 hash..." >&2
HASH=$(nix hash file --type sha256 "${BOARD}-recovery.zip")

# Clean up
rm -f "${BOARD}-recovery.zip"

echo "[+] Recovery image hash for $BOARD: $HASH" >&2
echo "$HASH"