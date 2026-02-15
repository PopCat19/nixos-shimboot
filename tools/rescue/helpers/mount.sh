#!/usr/bin/env bash
# mount.sh
#
# Purpose: Handle mount, unmount, and remount operations for rescue system.
#
# This module:
# - Mounts target partition with specified mode (ro/rw)
# - Handles pre-existing mounts from UDisks/udiskie
# - Provides remount functionality for switching modes
# - Manages MOUNTED state variable

source "${BASH_SOURCE[0]%/*}/common.sh"

mount_system() {
	local mode="${1:-ro}"

	if [[ "$MOUNTED" -eq 1 ]]; then
		log_warn "System already mounted"
		return 0
	fi

	# Preemptively unmount target device (protect against udiskie/udisks)
	local pre_mps
	pre_mps="$(lsblk -no MOUNTPOINT "$TARGET_PARTITION" 2>/dev/null | sed '/^$/d' || true)"

	if [[ -n "$pre_mps" ]]; then
		log_warn "Device $TARGET_PARTITION already mounted (possibly by UDisks):"
		echo "$pre_mps"

		while IFS= read -r mp; do
			[[ -z "$mp" ]] && continue
			log_info "Attempting to unmount pre-existing mount $mp..."
			umount "$mp" 2>/dev/null || umount -l "$mp" 2>/dev/null || {
				log_warn "Could not unmount $mp (may require manual unmount)"
			}
		done <<<"$pre_mps"

		sleep 0.5

		# Final check
		if lsblk -no MOUNTPOINT "$TARGET_PARTITION" 2>/dev/null | grep -q '\S'; then
			log_error "Failed to unmount existing mounts for $TARGET_PARTITION; aborting"
			return 1
		fi

		log_success "Pre-existing mounts cleared for $TARGET_PARTITION"
	fi

	mkdir -p "$MOUNTPOINT"

	log_step "Mount" "Mounting rootfs ($mode)"
	if ! mount -o "$mode" "$TARGET_PARTITION" "$MOUNTPOINT"; then
		log_error "Failed to mount $TARGET_PARTITION"
		return 1
	fi

	MOUNTED=1
	# shellcheck disable=SC2034 # Global state set for use by other modules
	PROFILE_DIR="$MOUNTPOINT/nix/var/nix/profiles"

	log_info "Mounted: $TARGET_PARTITION → $MOUNTPOINT"
	return 0
}

unmount_system() {
	if [[ "$MOUNTED" -eq 0 ]]; then
		log_info "System not mounted"
		return 0
	fi

	# Unmount dependent mounts first
	local deps=("$MOUNTPOINT/dev" "$MOUNTPOINT/proc" "$MOUNTPOINT/sys" "$MOUNTPOINT/home")
	for dep in "${deps[@]}"; do
		if mountpoint -q "$dep" 2>/dev/null; then
			log_info "Unmounting $dep"
			umount "$dep" 2>/dev/null || umount -l "$dep" 2>/dev/null || true
		fi
	done

	if mountpoint -q "$MOUNTPOINT" 2>/dev/null; then
		log_info "Unmounting $MOUNTPOINT"
		umount "$MOUNTPOINT" 2>/dev/null || umount -l "$MOUNTPOINT" 2>/dev/null || {
			log_warn "Failed to unmount $MOUNTPOINT"
			return 1
		}
	fi

	MOUNTED=0
	log_success "System unmounted"
	return 0
}

remount_system_rw() {
	if [[ "$MOUNTED" -eq 0 ]]; then
		mount_system "rw"
		return $?
	fi

	if mount | grep " $MOUNTPOINT " | grep -q "\bro\b"; then
		log_info "Remounting $MOUNTPOINT read-write..."
		mount -o remount,rw "$TARGET_PARTITION" "$MOUNTPOINT" || {
			log_error "Failed to remount read-write"
			return 1
		}
		log_success "Remounted $MOUNTPOINT read-write"
	fi
	return 0
}

remount_system_ro() {
	if [[ "$MOUNTED" -eq 0 ]]; then
		mount_system "ro"
		return $?
	fi

	if mount | grep " $MOUNTPOINT " | grep -q "\brw\b"; then
		sync
		log_info "Remounting $MOUNTPOINT read-only..."
		mount -o remount,ro "$TARGET_PARTITION" "$MOUNTPOINT" || {
			log_error "Failed to remount read-only"
			return 1
		}
		log_success "Remounted $MOUNTPOINT read-only"
	fi
	return 0
}

safe_unmount() {
	local mp="$1"
	umount "$mp" >/dev/null 2>&1 || umount -l "$mp" >/dev/null 2>&1 || true
}

get_mount_mode() {
	if [[ "$MOUNTED" -eq 0 ]]; then
		echo "unmounted"
	elif mount | grep "$MOUNTPOINT" | grep -q "ro,"; then
		echo "ro"
	else
		echo "rw"
	fi
}
