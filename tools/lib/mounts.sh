# mounts.sh
#
# Purpose: Provide shared mount and loop device management functions
#
# This module:
# - Sets up and tears down loop devices
# - Provides safe unmount with lazy fallback
# - Manages cleanup traps

# shellcheck shell=bash

# Detach a loop device if it exists
detach_loop() {
	local loopdev="$1"
	if [[ -n "$loopdev" ]] && losetup "$loopdev" >/dev/null 2>&1; then
		sudo losetup -d "$loopdev" 2>/dev/null || true
	fi
}

# Safely unmount a mount point with lazy fallback
safe_unmount() {
	local mp="$1"
	if [[ -z "$mp" ]]; then
		return 0
	fi
	if mountpoint -q "$mp" 2>/dev/null; then
		umount "$mp" 2>/dev/null || umount -l "$mp" 2>/dev/null || true
	fi
}

# Mount a filesystem read-only
mount_ro() {
	local source="$1"
	local target="$2"
	mkdir -p "$target"
	sudo mount -o ro "$source" "$target"
}

# Mount a filesystem read-write
mount_rw() {
	local source="$1"
	local target="$2"
	mkdir -p "$target"
	sudo mount -o rw "$source" "$target"
}

# Setup loop device and return path
setup_loop() {
	local image="$1"
	local loopdev
	loopdev="$(sudo losetup --show -fP "$image")"
	echo "$loopdev"
}

# Cleanup mounts and loop devices from a workdir
cleanup_mounts_and_loops() {
	local workdir="$1"
	local loopdev="$2"
	shift 2
	local mount_points=("$@")

	set +e
	for mp in "${mount_points[@]}"; do
		safe_unmount "$mp"
	done
	if [[ -n "$loopdev" ]]; then
		detach_loop "$loopdev"
	fi
	if [[ -n "$workdir" ]]; then
		rm -rf "$workdir"
	fi
	set -e
}
