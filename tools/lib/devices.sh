# devices.sh
#
# Purpose: Provide device and disk enumeration helpers
#
# This module:
# - Enumerates block devices
# - Detects system disks
# - Filters safe device candidates
# - Provides lsblk parsing

# shellcheck shell=bash

list_block_devices() {
	local devices=()
	while read -r dev; do
		devices+=("$dev")
	done < <(lsblk -dn -o NAME -p | grep -E '^/dev/(sd| nvme|vd)' | sort)
	printf '%s\n' "${devices[@]}"
}

is_system_disk() {
	local dev="$1"
	local root_dev
	root_dev=$(findmnt -n -o SOURCE / | sed 's/[0-9]*$//')

	[[ "$dev" == "$root_dev" ]] || [[ "$dev" == "${root_dev}p"* ]]
}

get_device_size() {
	local dev="$1"
	blockdev --getsize64 "$dev" 2>/dev/null || echo 0
}

filter_safe_devices() {
	local min_size="${1:-1073741824}"
	local devices=()

	while read -r dev; do
		if is_system_disk "$dev"; then
			continue
		fi
		local size
		size=$(get_device_size "$dev")
		if [[ $size -ge $min_size ]]; then
			devices+=("$dev")
		fi
	done < <(list_block_devices)

	printf '%s\n' "${devices[@]}"
}

find_mounted_device() {
	local path="$1"
	findmnt -n -o SOURCE "$path" 2>/dev/null | sed 's/p[0-9]*$//' | sed 's/[0-9]*$//'
}

is_mounted() {
	local path="$1"
	findmnt -n "$path" >/dev/null 2>&1
}

get_mount_point() {
	local dev="$1"
	findmnt -n -o TARGET "$dev" 2>/dev/null
}

is_loop_device() {
	[[ "$1" == /dev/loop* ]]
}

cleanup_loop() {
	local loopdev="$1"
	if [[ -b "$loopdev" ]]; then
		if is_mounted "$(losetup -n -o "$loopdev" 2>/dev/null)"; then
			return 1
		fi
		losetup -d "$loopdev" 2>/dev/null || true
	fi
}
