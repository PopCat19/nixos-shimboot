#!/usr/bin/env bash

# test-devices.sh
#
# Purpose: Unit tests for devices.sh
#
# This module:
# - Tests device enumeration
# - Tests mount detection

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../tools/lib" && pwd)"

# shellcheck source=logging.sh
source "$LIB_DIR/logging.sh"
# shellcheck source=devices.sh
source "$LIB_DIR/devices.sh"

test_is_loop_device() {
	if ! is_loop_device /dev/loop0; then
		echo "FAIL: is_loop_device loop0"
		return 1
	fi

	if is_loop_device /dev/sda; then
		echo "FAIL: is_loop_device sda"
		return 1
	fi

	echo "PASS: is_loop_device"
	return 0
}

test_is_mounted() {
	if ! is_mounted /; then
		echo "FAIL: is_mounted root"
		return 1
	fi

	if is_mounted /this/does/not/exist/12345; then
		echo "FAIL: is_mounted non-existent"
		return 1
	fi

	echo "PASS: is_mounted"
	return 0
}

test_get_mount_point() {
	local mp
	mp=$(get_mount_point /)
	if [[ -z "$mp" ]]; then
		echo "FAIL: get_mount_point root"
		return 1
	fi

	echo "PASS: get_mount_point"
	return 0
}

test_get_device_size() {
	local size
	size=$(get_device_size /dev/null 2>/dev/null)
	if [[ -z "$size" ]]; then
		echo "FAIL: get_device_size"
		return 1
	fi

	echo "PASS: get_device_size"
	return 0
}

test_find_mounted_device() {
	local dev
	dev=$(find_mounted_device /)
	if [[ -z "$dev" ]]; then
		echo "FAIL: find_mounted_device root"
		return 1
	fi

	echo "PASS: find_mounted_device"
	return 0
}

main() {
	test_is_loop_device
	test_is_mounted
	test_get_mount_point
	test_get_device_size
	test_find_mounted_device
	echo "All devices tests passed"
}

main "$@"
