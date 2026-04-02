# cleanup.sh
#
# Purpose: Provide trap-based cleanup helpers
#
# This module:
# - Sets up cleanup traps
# - Registers cleanup handlers for mounts, loops, temps
# - Provides safe unmount helpers

# shellcheck shell=bash

_CLEANUP_STACK=()

cleanup_register() {
	_CLEANUP_STACK+=("$1")
}

cleanup_execute() {
	local IFS=$'\n'
	for handler in $(tac <<<"${_CLEANUP_STACK[*]}"); do
		eval "$handler" 2>/dev/null || true
	done
	_CLEANUP_STACK=()
}

trap_cleanup() {
	trap cleanup_execute EXIT
	trap 'cleanup_execute; exit 130' INT TERM
}

add_mount_cleanup() {
	local path="$1"
	cleanup_register "if mountpoint -q '$path' 2>/dev/null; then umount '$path' 2>/dev/null || true; fi"
}

add_loop_cleanup() {
	local loopdev="$1"
	cleanup_register "losetup -d '$loopdev' 2>/dev/null || true"
}

add_temp_cleanup() {
	local temp_dir="$1"
	cleanup_register "rm -rf '$temp_dir' 2>/dev/null || true"
}

safe_umount() {
	local path="$1"
	if ! mountpoint -q "$path" 2>/dev/null; then
		return 0
	fi

	if umount "$path" 2>/dev/null; then
		return 0
	fi

	log_warn "Normal umount failed, trying lazy umount"
	umount -l "$path" 2>/dev/null || true
}

lazy_umount() {
	local path="$1"
	if mountpoint -q "$path" 2>/dev/null; then
		umount -l "$path" 2>/dev/null || true
	fi
}
