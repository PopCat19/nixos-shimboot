#!/usr/bin/env bash
# filesystem.sh
#
# Purpose: Provide filesystem operations (chroot, disk usage, fsck).
#
# This module:
# - Enters chroot environment for system repair
# - Checks disk usage and directory sizes
# - Runs filesystem health checks with gum spin

source "${BASH_SOURCE[0]%/*}/common.sh"
source "${BASH_SOURCE[0]%/*}/mount.sh"

chroot_system() {
	if [[ "$MOUNTED" -eq 0 ]]; then
		mount_system "rw" || return 1
	fi

	# Detect suitable shell path in rootfs
	local bash_path=""
	if [[ -x "$MOUNTPOINT/bin/bash" ]]; then
		bash_path="/bin/bash"
	elif [[ -x "$MOUNTPOINT/run/current-system/sw/bin/bash" ]]; then
		bash_path="/run/current-system/sw/bin/bash"
	elif [[ -x "$MOUNTPOINT/bin/sh" ]]; then
		bash_path="/bin/sh"
	else
		log_error "No shell found inside rootfs (bash or sh)"
		return 1
	fi

	log_info "Entering chroot environment..."
	log_warn "Type 'exit' to return to rescue helper"
	log_info "Shell: $bash_path"

	# Bind essential filesystems for chroot
	mount --bind /dev "$MOUNTPOINT/dev"
	mount --bind /proc "$MOUNTPOINT/proc"
	mount --bind /sys "$MOUNTPOINT/sys"

	# Enter chroot
	chroot "$MOUNTPOINT" "$bash_path" || true

	# Cleanly unmount
	umount "$MOUNTPOINT/sys" "$MOUNTPOINT/proc" "$MOUNTPOINT/dev" 2>/dev/null || true

	log_success "Exited chroot environment"
}

check_disk_usage() {
	log_info "Disk usage for $TARGET_PARTITION:"
	df -h "$MOUNTPOINT"
	echo
	log_info "Top directories by size:"
	du -h --max-depth=1 "$MOUNTPOINT" 2>/dev/null | sort -hr | head -n 10
}

run_fsck() {
	log_section "Filesystem Health Check"

	# Need to unmount first
	if [[ "$MOUNTED" -eq 1 ]]; then
		log_info "Unmounting for filesystem check..."
		unmount_system || return 1
	fi

	log_info "Running filesystem check on $TARGET_PARTITION..."

	gum spin --title "Checking filesystem..." -- e2fsck -n "$TARGET_PARTITION" || {
		log_warn "Filesystem check found issues"
		return 0
	}

	log_success "Filesystem check completed - no issues found"
	return 0
}

remount_rw() {
	if [[ "$MOUNTED" -eq 0 ]]; then
		mount_system "rw" || return 1
	else
		remount_system_rw || return 1
	fi
}

remount_ro() {
	if [[ "$MOUNTED" -eq 0 ]]; then
		mount_system "ro" || return 1
	else
		remount_system_ro || return 1
	fi
}

filesystem_menu() {
	log_section "Filesystem Operations"

	local options=(
		"Remount read-write"
		"Remount read-only"
		"Chroot into system"
		"Check disk usage"
		"Filesystem health check"
		"Back to main menu"
	)

	while true; do
		local choice
		choice=$(gum choose "${options[@]}" --header "Select filesystem operation:" --height 10)

		[[ -z "$choice" ]] && return 0

		case "$choice" in
		"Remount read-write")
			remount_rw
			log_success "Remounted read-write"
			;;
		"Remount read-only")
			remount_ro
			log_success "Remounted read-only"
			;;
		"Chroot into system")
			chroot_system
			;;
		"Check disk usage")
			if [[ "$MOUNTED" -eq 0 ]]; then
				mount_system "ro" || continue
			fi
			check_disk_usage
			;;
		"Filesystem health check")
			run_fsck
			;;
		"Back to main menu")
			return 0
			;;
		esac

		pause
	done
}
