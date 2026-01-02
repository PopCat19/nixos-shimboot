#!/usr/bin/env bash
# NixOS Shimboot Rescue Helper
#
# Purpose: Provide a unified interactive toolkit for inspecting and repairing
#          shimboot-based NixOS systems directly from a live environment.
# Dependencies: mount, umount, losetup, cgpt, nix, zstd, chroot
# Related: assemble-final.sh, write-shimboot-image.sh
#
# This script:
# - Mounts or repairs shimboot rootfs partitions
# - Manages and rolls back NixOS generations
# - Provides filesystem and rescue operations (chroot, fsck, usage)
# - Handles home backup, export, and import
# - Inspects and manages bootloader (kernel/initramfs/bootstrap scripts)
# - Detects automatically partition mapping across ChromeOS layouts
#
# Usage:
#   sudo ./tools/rescue-helper.sh [DEVICE|auto]
# Example:
#   sudo ./tools/rescue-helper.sh /dev/sdc5
#
# Notes:
#   - Runs read-only by default
#   - Write operations require confirmation
#   - Colorized output improves readability

set -euo pipefail

# === Colors & Logging ===
ANSI_CLEAR='\033[0m'
ANSI_BOLD='\033[1m'
ANSI_GREEN='\033[1;32m'
ANSI_BLUE='\033[1;34m'
ANSI_YELLOW='\033[1;33m'
ANSI_RED='\033[1;31m'
ANSI_CYAN='\033[1;36m'
ANSI_MAGENTA='\033[1;35m'

log_step() { printf "${ANSI_BOLD}${ANSI_BLUE}[%s] %s${ANSI_CLEAR}\n" "$1" "$2"; }
log_info() { printf "${ANSI_GREEN}  → %s${ANSI_CLEAR}\n" "$1"; }
log_warn() {
	# Use yellow triangle for better visibility and consistency
	printf "${ANSI_YELLOW}  ⚠ %s${ANSI_CLEAR}\n" "$1"
}
log_error() { printf "${ANSI_RED}  ✗ %s${ANSI_CLEAR}\n" "$1"; }
log_success() { printf "${ANSI_GREEN}  ✓ %s${ANSI_CLEAR}\n" "$1"; }
log_section() {
	printf "\n${ANSI_BOLD}${ANSI_CYAN}─── %s ───${ANSI_CLEAR}\n" "$1"
}

# Unified confirmation prompt helper for UX consistency
confirm_action() {
	read -rp "→ Confirm action? [y/N]: " _ans
	[[ "${_ans,,}" == "y" ]]
}

# === Configuration ===
TARGET_PARTITION="${1:-}"
MOUNTPOINT="/mnt/nixos-rescue"
EDITOR="${EDITOR:-nano}"
HOME_BACKUP_DIR="${HOME_BACKUP_DIR:-/tmp/home-backups}"

# === Global State ===
MOUNTED=0
PROFILE_DIR=""
LATEST_GEN=""
ROOTFS_PARTITION=""
BOOTLOADER_PARTITION=""

# --- Functions ---

detect_partition() {
	log_info "Auto-detecting NixOS shimboot partitions..."

	# Look for shimboot_rootfs:* partitions
	for part in /dev/sd[a-z][0-9] /dev/nvme[0-9]n1p[0-9]; do
		[[ -b "$part" ]] || continue

		# Check partition label
		local label
		label="$(lsblk -no PARTLABEL "$part" 2>/dev/null || true)"

		if [[ "$label" == shimboot_rootfs:* ]]; then
			log_info "Found shimboot rootfs: $part ($label)"

			if mkdir -p "$MOUNTPOINT" && mount -o ro "$part" "$MOUNTPOINT" 2>/dev/null; then
				if [[ -d "$MOUNTPOINT/nix" && -d "$MOUNTPOINT/etc/nixos" ]]; then
					TARGET_PARTITION="$part"
					umount "$MOUNTPOINT" 2>/dev/null
					return 0
				fi
				umount "$MOUNTPOINT" 2>/dev/null || true
			fi
		fi
	done

	if [[ -z "${TARGET_PARTITION:-}" ]]; then
		log_error "Could not auto-detect NixOS shimboot partition"
		log_info "Available partitions:"
		lsblk -o NAME,SIZE,PARTLABEL,MOUNTPOINT | grep -E "part|disk" || true
		return 1
	fi
}

ensure_root() {
	if [[ "$EUID" -ne 0 ]]; then
		log_error "This script must be run as root"
		log_info "Usage: sudo $0 [partition]"
		exit 1
	fi
}

# === Utility Helpers ===

# Pause for user confirmation (used across menus)
pause() { read -rp "Press Enter to continue..." _; }

# Remount to read-write mode if current MOUNTPOINT is read-only
remount_system_rw() {
	if mount | grep "$MOUNTPOINT" | grep -q "ro,"; then
		umount "$MOUNTPOINT" 2>/dev/null || true
		MOUNTED=0
		mount_system "rw"
		log_success "Remounted $MOUNTPOINT read-write."
	fi
}

# Safely unmount a bootloader or root partition (reuse across menus)
safe_unmount() {
	local mp="$1"
	umount "$mp" >/dev/null 2>&1 || umount -l "$mp" >/dev/null 2>&1 || true
}

#
# --- Robust Cleanup & Signal Handling (assemble-final parity) ---
#
cleanup() {
	set +e
	log_info "Rescue cleanup in progress..."

	# Unmount dependent mounts if present (include bootloader mount)
	for m in "/mnt/bootloader-rescue" "$MOUNTPOINT/home" "$MOUNTPOINT/dev" "$MOUNTPOINT/proc" "$MOUNTPOINT/sys" "$MOUNTPOINT"; do
		if mountpoint -q "$m" 2>/dev/null; then
			log_info "Unmounting $m"
			umount "$m" 2>/dev/null || umount -l "$m" 2>/dev/null || true
		fi
	done

	sync
	log_info "Cleanup complete."
	set -e
}

handle_interrupt() {
	echo
	log_warn "Keyboard interrupt detected — performing safe cleanup"
	trap - INT TERM EXIT
	cleanup
	log_error "Rescue Helper aborted by user."
	exit 130
}

# Trap all exit paths
trap cleanup EXIT TERM
trap handle_interrupt INT

mount_system() {
	local mode="${1:-ro}" # ro or rw

	if [[ "$MOUNTED" -eq 1 ]]; then
		log_warn "System already mounted"
		return 0
	fi

	# --- Preemptively unmount target device (protect against udiskie/udisks) ---
	local pre_mps
	pre_mps="$(lsblk -no MOUNTPOINT "$TARGET_PARTITION" 2>/dev/null | sed '/^$/d' || true)"
	if [[ -n "$pre_mps" ]]; then
		log_warn "Device $TARGET_PARTITION already mounted (possibly by UDisks):"
		echo "$pre_mps"
		while IFS= read -r mp; do
			[[ -z "$mp" ]] && continue
			log_info "Attempting to unmount pre-existing mount $mp..."
			umount "$mp" 2>/dev/null || umount -l "$mp" 2>/dev/null || log_warn "Could not unmount $mp (may require manual unmount)."
		done <<<"$pre_mps"
		sleep 0.5
		# Final check
		if lsblk -no MOUNTPOINT "$TARGET_PARTITION" 2>/dev/null | grep -q '\S'; then
			log_error "Failed to unmount existing mounts for $TARGET_PARTITION; aborting to avoid conflicts."
			exit 1
		fi
		log_success "Pre-existing mounts cleared for $TARGET_PARTITION."
	fi

	mkdir -p "$MOUNTPOINT"

	log_step "Mount" "Mounting rootfs ($mode)"
	if ! mount -o "$mode" "$TARGET_PARTITION" "$MOUNTPOINT"; then
		log_error "Failed to mount $TARGET_PARTITION"
		return 1
	fi

	MOUNTED=1
	PROFILE_DIR="$MOUNTPOINT/nix/var/nix/profiles"

	log_info "Mounted: $TARGET_PARTITION → $MOUNTPOINT"
	return 0
}

# === Generation Management ===

list_generations() {
	log_section "NixOS Generations"

	if [[ ! -d "$PROFILE_DIR" ]]; then
		log_error "Profile directory not found: $PROFILE_DIR"
		return 1
	fi

	# Get all system-*-link symlinks
	mapfile -t generations < <(find "$PROFILE_DIR" -maxdepth 1 -type l -name "system-*-link" | sort -V)

	if [[ ${#generations[@]} -eq 0 ]]; then
		log_warn "No generations found"
		return 1
	fi

	printf "%-4s %-20s %-12s %-10s %s\n" "GEN" "DATE" "SIZE" "CURRENT" "PATH"
	echo "─────────────────────────────────────────────────────────────────────────────"

	local current_gen
	current_gen="$(readlink -f "$PROFILE_DIR/system" 2>/dev/null || true)"

	for gen in "${generations[@]}"; do
		local gen_num
		gen_num="$(basename "$gen" | sed 's/system-\([0-9]*\)-link/\1/')"

		local gen_path
		gen_path="$(readlink -f "$gen")"

		local gen_date
		gen_date="$(stat -c %y "$gen" | cut -d' ' -f1,2 | cut -d'.' -f1)"

		local gen_size
		gen_size="$(du -sh "$gen_path" 2>/dev/null | cut -f1 || echo "?")"

		local is_current=""
		if [[ "$gen_path" == "$current_gen" ]]; then
			is_current="✓ (active)"
		fi

		printf "%-4s %-20s %-12s %-10s %s\n" "$gen_num" "$gen_date" "$gen_size" "$is_current" "$gen_path"
	done

	return 0
}

rollback_generation() {
	log_section "Rollback Generation"

	list_generations

	echo
	read -rp "Enter generation number to rollback to (or 'cancel'): " gen_num

	if [[ "$gen_num" == "cancel" ]]; then
		log_info "Rollback cancelled"
		return 0
	fi

	local target_gen="$PROFILE_DIR/system-${gen_num}-link"

	if [[ ! -L "$target_gen" ]]; then
		log_error "Generation $gen_num not found"
		return 1
	fi

	local target_path
	target_path="$(readlink -f "$target_gen")"

	log_warn "This will switch the system profile to generation $gen_num"
	log_info "Target: $target_path"

	if ! confirm_action; then
		log_info "Rollback cancelled"
		return 0
	fi

	# Create new system profile symlink
	log_info "Rolling back to generation $gen_num..."
	rm -f "$PROFILE_DIR/system"
	ln -s "$target_path" "$PROFILE_DIR/system"

	log_success "Rolled back to generation $gen_num"
	log_info "Reboot for changes to take effect"

	return 0
}

delete_generations() {
	log_section "Delete Old Generations"

	list_generations

	echo
	log_warn "WARNING: Deleting generations is irreversible!"
	read -rp "Keep last N generations (default: 3): " keep_count
	keep_count="${keep_count:-3}"

	if ! [[ "$keep_count" =~ ^[0-9]+$ ]]; then
		log_error "Invalid number: $keep_count"
		return 1
	fi

	# Get all generations, sorted
	mapfile -t generations < <(find "$PROFILE_DIR" -maxdepth 1 -type l -name "system-*-link" | sort -V)

	local total_count=${#generations[@]}
	local delete_count=$((total_count - keep_count))

	if [[ $delete_count -le 0 ]]; then
		log_info "No generations to delete (total: $total_count, keep: $keep_count)"
		return 0
	fi

	log_warn "Will delete $delete_count generation(s), keeping newest $keep_count"
	if ! confirm_action; then
		log_info "Deletion cancelled"
		return 0
	fi

	# Delete old generations
	for ((i = 0; i < delete_count; i++)); do
		local gen="${generations[$i]}"
		local gen_num
		gen_num="$(basename "$gen" | sed 's/system-\([0-9]*\)-link/\1/')"

		log_info "Deleting generation $gen_num..."
		rm -f "$gen"
	done

	# Garbage collect
	log_info "Running garbage collection..."
	nix store --store "$MOUNTPOINT/nix/store" collect-garbage -d || log_warn "Garbage collection had issues"

	log_success "Deleted $delete_count generation(s)"

	return 0
}

view_generation_diff() {
	log_section "Generation Diff"

	list_generations

	echo
	read -rp "Enter first generation number: " gen1
	read -rp "Enter second generation number: " gen2

	local gen1_path="$PROFILE_DIR/system-${gen1}-link"
	local gen2_path="$PROFILE_DIR/system-${gen2}-link"

	if [[ ! -L "$gen1_path" ]] || [[ ! -L "$gen2_path" ]]; then
		log_error "Invalid generation number(s)"
		return 1
	fi

	log_info "Comparing generation $gen1 → $gen2..."

	# Use nix store diff-closures
	local path1 path2
	path1="$(readlink -f "$gen1_path")"
	path2="$(readlink -f "$gen2_path")"

	nix store --store "$MOUNTPOINT/nix/store" diff-closures "$path1" "$path2"

	return 0
}

# === Filesystem Operations ===

filesystem_menu() {
	log_section "Filesystem Operations"

	PS3="Select filesystem operation: "
	select opt in \
		"Remount read-write" \
		"Remount read-only" \
		"Chroot into system" \
		"Check disk usage" \
		"Filesystem health check" \
		"Back to main menu (0)"; do
		[[ "$REPLY" == "0" ]] && return 0
		case "$opt" in
		"Remount read-write")
			if [[ "$MOUNTED" -eq 1 ]]; then
				umount "$MOUNTPOINT"
				MOUNTED=0
			fi
			mount_system "rw"
			log_success "Remounted read-write"
			;;
		"Remount read-only")
			if [[ "$MOUNTED" -eq 1 ]]; then
				umount "$MOUNTPOINT"
				MOUNTED=0
			fi
			mount_system "ro"
			log_success "Remounted read-only"
			;;
		"Chroot into system")
			if [[ "$MOUNTED" -eq 0 ]]; then
				mount_system "rw"
			fi
			log_info "Entering chroot environment..."
			log_warn "Type 'exit' to return to rescue helper (if /bin/bash missing, try /run/current-system/sw/bin/bash)"

			# Detect suitable shell path in rootfs
			local bash_path=""
			if [[ -x "$MOUNTPOINT/bin/bash" ]]; then
				bash_path="/bin/bash"
			elif [[ -x "$MOUNTPOINT/run/current-system/sw/bin/bash" ]]; then
				bash_path="/run/current-system/sw/bin/bash"
			elif [[ -x "$MOUNTPOINT/bin/sh" ]]; then
				bash_path="/bin/sh"
			else
				log_error "No shell found inside rootfs (bash or sh)."
				return 1
			fi

			# Bind essential filesystems for chroot
			mount --bind /dev "$MOUNTPOINT/dev"
			mount --bind /proc "$MOUNTPOINT/proc"
			mount --bind /sys "$MOUNTPOINT/sys"

			# Enter chroot
			chroot "$MOUNTPOINT" "$bash_path" || true

			# Cleanly unmount
			umount "$MOUNTPOINT/sys" "$MOUNTPOINT/proc" "$MOUNTPOINT/dev" || true
			;;
		"Check disk usage")
			log_info "Disk usage for $TARGET_PARTITION:"
			df -h "$MOUNTPOINT"
			echo
			log_info "Top directories by size:"
			du -h --max-depth=1 "$MOUNTPOINT" 2>/dev/null | sort -hr | head -n 10
			;;
		"Filesystem health check")
			log_info "Running filesystem check..."
			[[ "$MOUNTED" -eq 1 ]] && {
				umount "$MOUNTPOINT"
				MOUNTED=0
			}
			e2fsck -n "$TARGET_PARTITION" || log_warn "Filesystem check found issues"
			;;
		"Back to main menu")
			return 0
			;;
		*)
			log_warn "Invalid choice"
			;;
		esac
	done
}

# === Home Directory Management ===

home_menu() {
	log_section "Home Directory Management"

	if [[ "$MOUNTED" -eq 0 ]]; then
		mount_system "ro"
	fi

	# Ask user once where to store/read backups
	echo
	log_info "Current backup directory: $HOME_BACKUP_DIR"
	read -rp "Change backup directory? [y/N] " change_dir
	if [[ "$change_dir" =~ ^[Yy]$ ]]; then
		read -rp "Enter new backup directory path: " new_dir
		if [[ -n "$new_dir" ]]; then
			HOME_BACKUP_DIR="$new_dir"
		fi
	fi

	mkdir -p "$HOME_BACKUP_DIR"
	log_info "Using backup directory: $HOME_BACKUP_DIR"

	PS3="Select home directory operation: "
	select opt in \
		"Export home to zstd archive" \
		"Import home from zstd archive" \
		"List home contents" \
		"View backup archives" \
		"Back to main menu (0)"; do
		[[ "$REPLY" == "0" ]] && return 0
		case "$opt" in
		"Export home to zstd archive")
			log_info "Available users in /home:"
			ls -1 "$MOUNTPOINT/home" || log_warn "No users found"

			echo
			read -rp "Enter username to export: " username

			if [[ ! -d "$MOUNTPOINT/home/$username" ]]; then
				log_error "User home not found: $username"
				continue
			fi

			local timestamp
			timestamp="$(date +%Y%m%d_%H%M%S)"
			local archive_name="${username}_home_${timestamp}.tar.zst"
			local archive_path="$HOME_BACKUP_DIR/$archive_name"

			log_info "Exporting $username's home to $archive_path..."

			# Create metadata file
			local meta_file="/tmp/home_backup_meta_${timestamp}.txt"
			cat >"$meta_file" <<EOF
User: $username
Exported: $(date)
Source: $MOUNTPOINT/home/$username
Partition: $TARGET_PARTITION
EOF

			# Create archive with progress
			tar -C "$MOUNTPOINT/home" -cf - "$username" --transform="s|^|$username/|" -C /tmp "$(basename "$meta_file")" |
				pv -s "$(du -sb "$MOUNTPOINT/home/$username" | cut -f1)" |
				zstd -T0 -19 >"$archive_path"

			rm -f "$meta_file"

			log_success "Exported to: $archive_path"
			log_info "Archive size: $(du -h "$archive_path" | cut -f1)"
			;;
		"Import home from zstd archive")
			log_info "Available archives in $HOME_BACKUP_DIR:"
			ls -1h "$HOME_BACKUP_DIR"/*.tar.zst 2>/dev/null || log_warn "No archives found"
			echo
			read -rp "Would you like to import from a different directory? [y/N]: " alt
			if [[ "$alt" =~ ^[Yy]$ ]]; then
				read -rp "Enter source directory path: " import_dir
				if [[ -d "$import_dir" ]]; then
					HOME_BACKUP_DIR="$import_dir"
					log_info "Import directory switched to: $HOME_BACKUP_DIR"
				else
					log_warn "Directory not found, using default: $HOME_BACKUP_DIR"
				fi
			fi

			log_info "Available archives in $HOME_BACKUP_DIR:"
			ls -1h "$HOME_BACKUP_DIR"/*.tar.zst 2>/dev/null || log_warn "No archives found"

			echo
			read -rp "Enter archive filename: " archive_file

			local archive_path="$HOME_BACKUP_DIR/$archive_file"
			if [[ ! -f "$archive_path" ]]; then
				log_error "Archive not found: $archive_path"
				continue
			fi

			log_warn "This will overwrite existing home directory contents!"
			if ! confirm_action; then
				log_info "Import cancelled"
				continue
			fi

			remount_system_rw

			log_info "Importing from $archive_path..."

			pv "$archive_path" | zstd -d | tar -C "$MOUNTPOINT/home" -xf -

			log_success "Import complete"
			;;
		"List home contents")
			log_info "Users in /home:"
			ls -lh "$MOUNTPOINT/home" || log_warn "No users found"

			echo
			read -rp "Enter username to inspect (or Enter to skip): " username

			if [[ -n "$username" ]] && [[ -d "$MOUNTPOINT/home/$username" ]]; then
				log_info "Contents of /home/$username:"
				du -h --max-depth=1 "$MOUNTPOINT/home/$username" 2>/dev/null | sort -hr | head -n 20
			fi
			;;
		"View backup archives")
			log_info "Backup archives in $HOME_BACKUP_DIR:"
			ls -lh "$HOME_BACKUP_DIR" || log_warn "No backups found"
			;;
		"Back to main menu")
			return 0
			;;
		*)
			log_warn "Invalid choice"
			;;
		esac
	done
}

# === Bootstrap Helper Functions ===

call_bootloader_backup_restore() {
	local bootloader_dir="$1"
	local backup_dir="$2"

	PS3="Select bootloader backup/restore operation: "
	select action in \
		"Backup bootloader files" \
		"Restore from backup" \
		"Back to bootstrap menu (0)"; do
		if [[ "$REPLY" == "0" || "$action" == "Back to bootstrap menu (0)" ]]; then
			break
		fi
		case "$action" in
		"Backup bootloader files")
			mkdir -p "$backup_dir"
			local timestamp
			timestamp="$(date +%Y%m%d_%H%M%S)"
			local backup_archive="$backup_dir/bootloader_backup_${timestamp}.tar.gz"

			log_info "Creating backup of bootloader files to: $backup_archive"
			tar -czf "$backup_archive" -C "$(dirname "$bootloader_dir")" "$(basename "$bootloader_dir")" 2>/dev/null || {
				log_warn "Failed to create backup, trying alternative method..."
				tar -czf "$backup_archive" -C "$bootloader_dir" . 2>/dev/null || log_error "Backup failed"
			}

			if [[ -f "$backup_archive" ]]; then
				log_success "Backup created: $backup_archive"
				log_info "Backup size: $(du -h "$backup_archive" | cut -f1)"
			fi
			;;
		"Restore from backup")
			log_info "Available backups in $backup_dir:"
			ls -la "$backup_dir"/*.tar.gz 2>/dev/null || log_warn "No backups found"

			echo
			read -rp "Enter backup filename to restore: " backup_file
			local backup_path="$backup_dir/$backup_file"

			if [[ ! -f "$backup_path" ]]; then
				log_error "Backup not found: $backup_path"
				continue
			fi

			log_warn "This will overwrite bootloader files!"
			read -rp "Confirm restore? [y/N]: " confirm
			if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
				log_info "Restore cancelled"
				continue
			fi

			# Remount read-write if needed
			if mount | grep "$MOUNTPOINT" | grep -q "ro,"; then
				umount "$MOUNTPOINT"
				MOUNTED=0
				mount_system "rw"
			fi

			log_info "Restoring bootloader from: $backup_path"
			tar -xzf "$backup_path" -C "$(dirname "$bootloader_dir")" || log_error "Restore failed"

			log_success "Bootloader restored from backup"
			;;
		esac
	done
}

display_bootloader_kernel_info() {
	local device="$1"
	local kernel_part="/dev/${device}2"

	log_info "Kernel partition: $kernel_part"
	log_info "Size: $(lsblk -no SIZE "$kernel_part")"

	log_info "Kernel signature (first block strings):"
	dd if="$kernel_part" bs=1M count=1 2>/dev/null | strings | head -n 10 || log_warn "Kernel metadata not visible"
	log_info "Note: ChromeOS vbutil_kernel blobs may not expose 'Linux version' directly."
}

#
# === Bootstrap Tools (Inspection + Management) ===
#
# Unifies inspection and management operations to remove redundant menus.
# Auto-detects the bootloader partition (p3) or fallback directory in the rootfs.
#
bootstrap_menu() {
	log_section "Bootstrap Tools"

	local backup_dir="/tmp/bootloader-backup"
	local boot_mnt="/mnt/bootloader-rescue"
	local device bootloader_dev bootloader_dir
	device="$(lsblk -no PKNAME "$TARGET_PARTITION" 2>/dev/null || true)"
	bootloader_dev="/dev/${device}3"

	# Mount logic consolidated
	ensure_bootloader_mounted() {
		if [[ -b "$bootloader_dev" && ! -d "$boot_mnt/bin" ]]; then
			mkdir -p "$boot_mnt"
			mount -o ro "$bootloader_dev" "$boot_mnt" 2>/dev/null || true
		fi
		if [[ -d "$boot_mnt/bin" ]]; then
			bootloader_dir="$boot_mnt"
			log_info "Bootloader partition mounted: $bootloader_dev → $boot_mnt"
		elif [[ -d "$MOUNTPOINT/bootloader" ]]; then
			bootloader_dir="$MOUNTPOINT/bootloader"
			log_info "Using inline bootloader directory inside rootfs"
		else
			log_error "Bootloader directory not found (no partition or inline copy)"
			return 1
		fi
	}

	ensure_bootloader_mounted || return 1

	PS3="Select bootstrap operation: "
	select action in \
		"List bootloader layout" \
		"View bootstrap.sh" \
		"Edit bootstrap.sh" \
		"Backup or Restore bootloader" \
		"Inspect kernel/initramfs" \
		"Check ChromeOS GPT flags" \
		"Unmount and return (0)"; do
		if [[ "$REPLY" == "0" || "$action" == "Unmount and return (0)" ]]; then
			break
		fi
		case "$action" in
		"List bootloader layout")
			find "$bootloader_dir" -maxdepth 2 -type f -exec ls -lah {} \; | head -n 25
			;;
		"View bootstrap.sh")
			if [[ -f "$bootloader_dir/bin/bootstrap.sh" ]]; then
				less "$bootloader_dir/bin/bootstrap.sh"
			else
				log_error "bootstrap.sh not found in $bootloader_dir/bin"
			fi
			;;
		"Edit bootstrap.sh")
			log_info "Mount temporarily RW and open with $EDITOR..."
			mount -o remount,rw "$bootloader_dev" 2>/dev/null || true
			"$EDITOR" "$bootloader_dir/bin/bootstrap.sh"
			mount -o remount,ro "$bootloader_dev" 2>/dev/null || true
			;;
		"Backup or Restore bootloader")
			call_bootloader_backup_restore "$bootloader_dir" "$backup_dir"
			;;
		"Inspect kernel/initramfs")
			display_bootloader_kernel_info "$device"
			;;
		"Check ChromeOS GPT flags")
			if command -v cgpt >/dev/null; then
				local disk_dev
				disk_dev="/dev/$(lsblk -no PKNAME "$TARGET_PARTITION" 2>/dev/null)"
				if [[ -b "$disk_dev" ]]; then
					log_info "Inspecting GPT of $disk_dev"
					cgpt show "$disk_dev" || log_warn "cgpt show failed (non‑ChromeOS GPT?)"
				else
					log_warn "Could not determine parent disk for $TARGET_PARTITION"
				fi
			else
				log_warn "cgpt not available"
			fi
			;;
		esac
	done

	safe_unmount "$boot_mnt"
	log_info "Unmounted bootloader partition"
}

# === Main Menu ===

main_menu() {
	while true; do
		log_section "NixOS Shimboot Rescue Helper"

		echo "System: $TARGET_PARTITION"
		echo "Mount: $MOUNTPOINT (mounted: $(if [[ "$MOUNTED" -eq 1 ]]; then echo "yes"; else echo "no"; fi))"
		echo

		PS3="Select operation category: "
		select category in \
			"Generation Management" \
			"Filesystem Operations" \
			"Bootstrap Tools" \
			"Home Directory Management" \
			"Stage-2 Activation Script (legacy)" \
			"Exit (0)"; do
			if [[ "$REPLY" == "0" || "$category" == "Exit (0)" ]]; then
				log_info "Goodbye!"
				exit 0
			fi
			case "$category" in
			"Generation Management")
				if [[ "$MOUNTED" -eq 0 ]]; then
					mount_system "ro"
				fi

				PS3="Select generation operation: "
				select opt in \
					"List generations" \
					"Rollback generation" \
					"Delete old generations" \
					"View generation diff" \
					"Back to main menu"; do
					if [[ "$REPLY" == "0" || "$opt" == "Back to main menu" ]]; then
						break
					fi
					case "$opt" in
					"List generations")
						list_generations
						;;
					"Rollback generation")
						remount_system_rw
						rollback_generation
						;;
					"Delete old generations")
						remount_system_rw
						delete_generations
						;;
					"View generation diff")
						view_generation_diff
						;;
					"Back to main menu")
						break
						;;
					*)
						log_warn "Invalid choice"
						;;
					esac
				done
				;;
			"Filesystem Operations")
				filesystem_menu
				;;
			"Bootstrap Tools")
				bootstrap_menu
				;;
			"Home Directory Management")
				home_menu
				;;
			"Stage-2 Activation Script (legacy)")
				if [[ "$MOUNTED" -eq 0 ]]; then
					mount_system "ro"
				fi

				# Find latest generation
				mapfile -t GENERATIONS < <(find "$PROFILE_DIR" -maxdepth 1 -type l -name "system-*-link" | sort -V)
				LATEST_GEN="${GENERATIONS[-1]:-}"

				if [[ -z "$LATEST_GEN" ]]; then
					log_error "No generations found"
					continue
				fi

				local latest_target
				latest_target=$(readlink -f "$LATEST_GEN")
				local activate_path="$MOUNTPOINT$latest_target/activate"

				if [[ ! -f "$activate_path" ]]; then
					log_error "Activation script not found"
					continue
				fi

				log_info "Activation script: $activate_path"

				PS3="Select action: "
				select opt in \
					"List first 40 lines" \
					"Search (custom grep pattern)" \
					"Edit activation script" \
					"Back"; do
					if [[ "$REPLY" == "0" || "$opt" == "Back" ]]; then
						break
					fi
					case "$opt" in
					"List first 40 lines")
						head -n 40 "$activate_path" | less
						;;
					"Search (custom grep pattern)")
						read -rp "Enter grep pattern: " pattern
						grep -n -H "$pattern" "$activate_path" || log_warn "No matches"
						;;
					"Edit activation script")
						remount_system_rw

						"$EDITOR" "$activate_path"
						log_success "Edit complete"
						;;
					"Back")
						break
						;;
					*)
						log_warn "Invalid choice"
						;;
					esac
				done
				;;
			"Exit" | "Exit (0)")
				log_info "Goodbye!"
				exit 0
				;;
			0)
				log_info "Goodbye!"
				exit 0
				;;
			*)
				log_warn "Invalid choice"
				;;
			esac

			break # Return to main menu after category
		done
	done
}

# === Main Execution ===

main() {
	ensure_root

	# Detect or validate partition
	if [[ -z "$TARGET_PARTITION" ]]; then
		if ! detect_partition; then
			exit 1
		fi
	fi

	# Validate partition exists
	if [[ ! -b "$TARGET_PARTITION" ]]; then
		log_error "Partition does not exist: $TARGET_PARTITION"
		lsblk
		exit 1
	fi

	# --- Interactive unmount check like write-shimboot-image.sh ---
	local mps
	mps="$(lsblk -no MOUNTPOINT "$TARGET_PARTITION" 2>/dev/null | sed '/^$/d' || true)"
	if [[ -n "$mps" ]]; then
		log_warn "Device $TARGET_PARTITION is currently mounted at:"
		echo "$mps"
		echo
		read -rp "Unmount $TARGET_PARTITION before continuing? [Y/n]: " ans
		ans="${ans:-Y}"
		if [[ "$ans" =~ ^[Yy]$ ]]; then
			while IFS= read -r mp; do
				[[ -z "$mp" ]] && continue
				log_info "Unmounting $mp..."
				umount "$mp" 2>/dev/null || {
					log_warn "Failed to unmount $mp automatically — please unmount manually."
				}
			done <<<"$mps"

			# Verify unmounted
			if lsblk -no MOUNTPOINT "$TARGET_PARTITION" 2>/dev/null | grep -q '\S'; then
				log_error "Device still mounted, aborting."
				exit 1
			fi

			log_success "Unmounted $TARGET_PARTITION."
		else
			log_error "Operation cancelled by user."
			exit 1
		fi
	fi

	log_info "Target partition: $TARGET_PARTITION"
	echo
	log_section "Rescue Environment Ready"
	log_info "Use menu prompts below for recovery operations."
	log_info "Press Ctrl+C anytime for safe cleanup."
	echo

	# Mount system initially (read-only)
	mount_system "ro"

	# Enter main menu
	main_menu
}

main "$@"
# end of file
