#!/usr/bin/env bash

# inspect-image.sh
#
# Purpose: Inspect shimboot image structure and verify rootfs and vendor contents
#
# This module:
# - Detects partitions automatically
# - Verifies rootfs and vendor contents
# - Provides colorized output

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"
# shellcheck source=logging.sh
source "$LIB_DIR/logging.sh"
# shellcheck source=runtime.sh
source "$LIB_DIR/runtime.sh"

# --- Default target image ---
IMAGE="${1:-work/shimboot.img}"

DETAIL_MODE="false"
if [[ "${2:-}" == "--details" ]]; then
	DETAIL_MODE="true"
fi

# --- Setup colors and logs ---
# Source shared colors
INSPECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=logging.sh
source "$INSPECT_DIR/../lib/logging.sh"

info() { echo -e "${COLOR_CYAN}$*${COLOR_CLEAR}"; }
warn() { echo -e "${COLOR_YELLOW}WARN:${COLOR_CLEAR} $*" >&2; }
error() { echo -e "${COLOR_RED}ERROR:${COLOR_CLEAR} $*" >&2; }
section() {
	echo
	echo -e "${COLOR_BOLD}${1}${COLOR_CLEAR}"
	echo -e "${COLOR_YELLOW}$(printf '%*s' 80 '' | tr ' ' '-')${COLOR_CLEAR}"
}

# --- Temporary directories and traps ---
WORKDIR="$(mktemp -d)"
LOOPDEV=""

cleanup() {
	set +e
	echo
	info "[CLEANUP] Unmounting and detaching..."
	for dir in "$WORKDIR/rootfs" "$WORKDIR/vendor" "$WORKDIR/bootloader"; do
		if mountpoint -q "$dir" 2>/dev/null; then
			sudo umount "$dir" >/dev/null 2>&1 || sudo umount -l "$dir" >/dev/null 2>&1
		fi
	done
	sleep 0.5
	if [[ -n "$LOOPDEV" && -b "$LOOPDEV" ]]; then
		sudo losetup -d "$LOOPDEV" >/dev/null 2>&1 || true
	fi
	rm -rf "$WORKDIR"
}
trap cleanup EXIT INT TERM

# --- Ensure image exists ---
if [[ ! -f "$IMAGE" ]]; then
	error "Image not found: $IMAGE"
	exit 1
fi

# --- Partition summary ---
section "Partition Table for $IMAGE"
sudo partx -o NR,START,END,SIZE,TYPE,NAME,UUID -g --show "$IMAGE" || true

echo
info "Detailed GPT structure:"
sudo gdisk -l "$IMAGE" | sed 's/^/  /'

# --- Setup loop device with partitions ---
echo
info "[INFO] Setting up loop device for image..."
LOOPDEV=$(sudo losetup --show -fP "$IMAGE")

# --- List partitions ---
info "Detected partitions under ${LOOPDEV}:"
lsblk -n -o NAME,SIZE,FSTYPE,MOUNTPOINT "${LOOPDEV}" | sed 's/^/  /'

# --- Detect rootfs partition dynamically ---
ROOTFS_PART="${LOOPDEV}p5"
VENDOR_PART="${LOOPDEV}p4"
BOOTLOADER_PART="${LOOPDEV}p3"
if [[ ! -b "$ROOTFS_PART" ]]; then
	warn "Cannot detect p5; falling back to p4 for rootfs"
	ROOTFS_PART="${LOOPDEV}p4"
fi

# --- Mount for inspection (read-only) ---
mkdir -p "$WORKDIR/rootfs"
info "[INFO] Mounting rootfs partition read-only..."
sudo mount -o ro "$ROOTFS_PART" "$WORKDIR/rootfs"

# --- Rootfs inspection ---
section "Top-level rootfs structure"
sudo ls -l --color=auto "$WORKDIR/rootfs" | head -n 25
if [[ "$(sudo ls "$WORKDIR/rootfs" | wc -l)" -gt 25 ]]; then
	echo "  ... (truncated)"
fi

# --- Identify init system ---
echo
if sudo test -f "$WORKDIR/rootfs/sbin/init"; then
	echo "OK Init found at: /sbin/init: $(sudo file "$WORKDIR/rootfs/sbin/init" | sed 's/^/  /')"
elif sudo test -f "$WORKDIR/rootfs/init"; then
	echo "OK Init found at: /init: $(sudo file "$WORKDIR/rootfs/init" | sed 's/^/  /')"
else
	echo "FAIL No init found at /sbin/init or /init"
fi

# --- Filesystem labels ---
echo
info "Filesystem labels (blkid):"
for part in "${LOOPDEV}"p{3,4,5}; do
	[[ -b "$part" ]] && sudo blkid "$part" | sed 's/^/  /'
done

# --- Optional details ---
if [[ "$DETAIL_MODE" == "true" ]]; then
	section "Bootloader and Vendor Summary"
	mkdir -p "$WORKDIR/bootloader" "$WORKDIR/vendor"
	if sudo mount -o ro "$BOOTLOADER_PART" "$WORKDIR/bootloader" 2>/dev/null; then
		echo "[BOOTLOADER] Contents:"
		sudo ls -l --color=auto "$WORKDIR/bootloader" | sed 's/^/  /'
		sudo umount "$WORKDIR/bootloader"
	else
		warn "Bootloader partition not found or could not be mounted."
	fi

	if sudo mount -o ro "$VENDOR_PART" "$WORKDIR/vendor" 2>/dev/null; then
		echo "[VENDOR] Sample directories:"
		sudo find "$WORKDIR/vendor" -maxdepth 2 -type d | head -n 15 | sed 's/^/  /'
		sudo umount "$WORKDIR/vendor"
	else
		warn "Vendor partition not found or could not be mounted."
	fi

	section "Image End Summary"
	echo "Loop device used: $LOOPDEV"
	echo "Temporary directory: $WORKDIR"
fi

echo
success() { echo -e "${COLOR_GREEN}$*${COLOR_CLEAR}"; }
success "OK Inspection complete: $IMAGE"
