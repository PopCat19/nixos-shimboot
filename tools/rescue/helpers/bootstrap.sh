#!/usr/bin/env bash
# bootstrap.sh
#
# Purpose: Inspect and manage bootloader (kernel, initramfs, bootstrap scripts, GPT).
#
# This module:
# - Lists bootloader layout and files
# - Views and edits bootstrap.sh
# - Creates and restores bootloader backups
# - Checks ChromeOS GPT flags with cgpt

source "${BASH_SOURCE[0]%/*}/common.sh"
source "${BASH_SOURCE[0]%/*}/mount.sh"

BOOT_MNT="/mnt/bootloader-rescue"
BACKUP_DIR="/tmp/bootloader-backup"

get_bootloader_device() {
	local device
	device="$(lsblk -no PKNAME "$TARGET_PARTITION" 2>/dev/null || true)"
	echo "/dev/${device}3"
}

get_parent_disk() {
	local device
	device="$(lsblk -no PKNAME "$TARGET_PARTITION" 2>/dev/null || true)"
	echo "/dev/$device"
}

ensure_bootloader_mounted() {
	local bootloader_dev="$1"

	if [[ -b "$bootloader_dev" && ! -d "$BOOT_MNT/bin" ]]; then
		mkdir -p "$BOOT_MNT"
		mount -o ro "$bootloader_dev" "$BOOT_MNT" 2>/dev/null || true
	fi

	if [[ -d "$BOOT_MNT/bin" ]]; then
		BOOTLOADER_DIR="$BOOT_MNT"
		log_info "Bootloader partition mounted: $bootloader_dev → $BOOT_MNT"
		return 0
	elif [[ -d "$MOUNTPOINT/bootloader" ]]; then
		BOOTLOADER_DIR="$MOUNTPOINT/bootloader"
		log_info "Using inline bootloader directory inside rootfs"
		return 0
	else
		log_error "Bootloader directory not found (no partition or inline copy)"
		return 1
	fi
}

list_bootloader_layout() {
	log_section "Bootloader Layout"

	find "${BOOTLOADER_DIR:-$BOOT_MNT}" -maxdepth 2 -type f -exec ls -lah {} \; | head -n 25
}

view_bootstrap_sh() {
	local bootstrap_path="${BOOTLOADER_DIR:-$BOOT_MNT}/bin/bootstrap.sh"

	if [[ -f "$bootstrap_path" ]]; then
		less "$bootstrap_path"
	else
		log_error "bootstrap.sh not found in ${BOOTLOADER_DIR:-$BOOT_MNT}/bin"
	fi
}

edit_bootstrap_sh() {
	local bootstrap_path="${BOOTLOADER_DIR:-$BOOT_MNT}/bin/bootstrap.sh"
	local bootloader_dev
	bootloader_dev=$(get_bootloader_device)

	if [[ ! -f "$bootstrap_path" ]]; then
		log_error "bootstrap.sh not found"
		return 1
	fi

	log_info "Mount temporarily RW and open with $EDITOR..."
	mount -o remount,rw "$bootloader_dev" 2>/dev/null || true

	"$EDITOR" "$bootstrap_path"

	mount -o remount,ro "$bootloader_dev" 2>/dev/null || true
	log_success "Edit complete"
}

backup_bootloader() {
	mkdir -p "$BACKUP_DIR"

	local timestamp backup_archive
	timestamp="$(date +%Y%m%d_%H%M%S)"
	backup_archive="$BACKUP_DIR/bootloader_backup_${timestamp}.tar.gz"

	log_info "Creating backup of bootloader files to: $backup_archive"

	local bootloader_dir="${BOOTLOADER_DIR:-$BOOT_MNT}"

	tar -czf "$backup_archive" -C "$(dirname "$bootloader_dir")" "$(basename "$bootloader_dir")" 2>/dev/null || {
		log_warn "Failed to create backup, trying alternative method..."
		tar -czf "$backup_archive" -C "$bootloader_dir" . 2>/dev/null || {
			log_error "Backup failed"
			return 1
		}
	}

	if [[ -f "$backup_archive" ]]; then
		log_success "Backup created: $backup_archive"
		log_info "Backup size: $(du -h "$backup_archive" | cut -f1)"
	fi
}

restore_bootloader() {
	log_info "Available backups in $BACKUP_DIR:"
	ls -la "$BACKUP_DIR"/*.tar.gz 2>/dev/null || {
		log_warn "No backups found"
		return 1
	}

	local backup_file
	backup_file=$(gum input --header "Enter backup filename to restore:" --value "")

	[[ -z "$backup_file" ]] && return 1

	local backup_path="$BACKUP_DIR/$backup_file"

	if [[ ! -f "$backup_path" ]]; then
		log_error "Backup not found: $backup_path"
		return 1
	fi

	log_warn "This will overwrite bootloader files!"

	if ! gum confirm "Proceed with restore?" --default=false; then
		log_info "Restore cancelled"
		return 0
	fi

	# Remount read-write if needed
	local bootloader_dev
	bootloader_dev=$(get_bootloader_device)

	if mount | grep "$MOUNTPOINT" | grep -q "ro,"; then
		umount "$MOUNTPOINT"
		# shellcheck disable=SC2034 # Global state modified for mount_system
		MOUNTED=0
		mount_system "rw"
	fi

	log_info "Restoring bootloader from: $backup_path"

	local bootloader_dir="${BOOTLOADER_DIR:-$BOOT_MNT}"
	tar -xzf "$backup_path" -C "$(dirname "$bootloader_dir")" || {
		log_error "Restore failed"
		return 1
	}

	log_success "Bootloader restored from backup"
}

backup_restore_menu() {
	local options=(
		"Backup bootloader files"
		"Restore from backup"
		"Back to bootstrap menu"
	)

	while true; do
		local choice
		choice=$(gum choose "${options[@]}" --header "Select bootloader backup/restore operation:" --height 8)

		[[ -z "$choice" ]] && return 0

		case "$choice" in
		"Backup bootloader files")
			backup_bootloader
			;;
		"Restore from backup")
			restore_bootloader
			;;
		"Back to bootstrap menu")
			return 0
			;;
		esac
	done
}

inspect_kernel_initramfs() {
	log_section "Kernel/Initramfs Info"

	local device
	device="$(lsblk -no PKNAME "$TARGET_PARTITION" 2>/dev/null || true)"
	local kernel_part="/dev/${device}2"

	log_info "Kernel partition: $kernel_part"
	log_info "Size: $(lsblk -no SIZE "$kernel_part")"

	log_info "Kernel signature (first block strings):"
	dd if="$kernel_part" bs=1M count=1 2>/dev/null | strings | head -n 10 || {
		log_warn "Kernel metadata not visible"
	}
	log_info "Note: ChromeOS vbutil_kernel blobs may not expose 'Linux version' directly."
}

check_gpt_flags() {
	log_section "ChromeOS GPT Flags"

	if ! command -v cgpt &>/dev/null; then
		log_warn "cgpt not available"
		return 1
	fi

	local disk_dev
	disk_dev=$(get_parent_disk)

	if [[ -b "$disk_dev" ]]; then
		log_info "Inspecting GPT of $disk_dev"
		cgpt show "$disk_dev" || {
			log_warn "cgpt show failed (non-ChromeOS GPT?)"
		}
	else
		log_warn "Could not determine parent disk for $TARGET_PARTITION"
	fi
}

bootstrap_menu() {
	log_section "Bootstrap Tools"

	local bootloader_dev
	bootloader_dev=$(get_bootloader_device)

	ensure_bootloader_mounted "$bootloader_dev" || return 1

	local options=(
		"List bootloader layout"
		"View bootstrap.sh"
		"Edit bootstrap.sh"
		"Backup or Restore bootloader"
		"Inspect kernel/initramfs"
		"Check ChromeOS GPT flags"
		"Unmount and return"
	)

	while true; do
		local choice
		choice=$(gum choose "${options[@]}" --header "Select bootstrap operation:" --height 12)

		[[ -z "$choice" ]] && break

		case "$choice" in
		"List bootloader layout")
			list_bootloader_layout
			;;
		"View bootstrap.sh")
			view_bootstrap_sh
			;;
		"Edit bootstrap.sh")
			edit_bootstrap_sh
			;;
		"Backup or Restore bootloader")
			backup_restore_menu
			;;
		"Inspect kernel/initramfs")
			inspect_kernel_initramfs
			;;
		"Check ChromeOS GPT flags")
			check_gpt_flags
			;;
		"Unmount and return")
			break
			;;
		esac

		pause
	done

	safe_unmount "$BOOT_MNT"
	log_info "Unmounted bootloader partition"
}
