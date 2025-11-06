#!/usr/bin/env bash

# Simple Rollback Script
#
# Purpose: Rollback NixOS generation by directly manipulating symlinks
# Dependencies: mount, umount, ln
# Related: assemble-final.sh
#
# This script manually rolls back the system profile when systemd is broken.

set -euo pipefail

# === Colors & Logging ===
ANSI_CLEAR='\033[0m'
ANSI_BOLD='\033[1m'
ANSI_GREEN='\033[1;32m'
ANSI_BLUE='\033[1;34m'
ANSI_YELLOW='\033[1;33m'
ANSI_RED='\033[1;31m'

log_step() {
	printf "${ANSI_BOLD}${ANSI_BLUE}[%s] %s${ANSI_CLEAR}\n" "$1" "$2"
}

log_info() {
	printf "${ANSI_GREEN}  → %s${ANSI_CLEAR}\n" "$1"
}

log_warn() {
	printf "${ANSI_YELLOW}  ! %s${ANSI_CLEAR}\n" "$1"
}

log_error() {
	printf "${ANSI_RED}  ✗ %s${ANSI_CLEAR}\n" "$1"
}

log_success() {
	printf "${ANSI_GREEN}  ✓ %s${ANSI_CLEAR}\n" "$1"
}

# === Configuration ===
TARGET_PARTITION="${1:-}"
MOUNTPOINT="/mnt/nixos-rollback"

# Auto-detect partition if not provided
if [ -z "$TARGET_PARTITION" ]; then
	log_info "Auto-detecting NixOS partitions..."
	# Look for common NixOS partition patterns
	for part in /dev/sd[a-z]5 /dev/sd[a-z]4 /dev/nvme[0-9]n1p5 /dev/nvme[0-9]n1p4; do
		if [ -b "$part" ] && mountpoint -q "$part" 2>/dev/null; then
			# Skip if already mounted
			continue
		fi
		# Try to mount and check if it looks like NixOS
		if mkdir -p "$MOUNTPOINT" && mount "$part" "$MOUNTPOINT" 2>/dev/null; then
			if [ -d "$MOUNTPOINT/nix" ] && [ -d "$MOUNTPOINT/etc/nixos" ]; then
				TARGET_PARTITION="$part"
				umount "$MOUNTPOINT" 2>/dev/null
				break
			fi
			umount "$MOUNTPOINT" 2>/dev/null
		fi
	done
	
	if [ -z "$TARGET_PARTITION" ]; then
		log_error "Could not auto-detect NixOS partition"
		log_info "Available partitions:"
		lsblk | grep -E "disk|part" || true
		exit 1
	fi
fi

# Check if running as root
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
	log_error "This script must be run as root"
	log_info "Usage: sudo $0 [partition]"
	log_info "Default partition: /dev/sdc5"
	exit 1
fi

# Validate partition exists
if [ ! -b "$TARGET_PARTITION" ]; then
	log_error "Target partition does not exist: $TARGET_PARTITION"
	log_info "Available partitions:"
	lsblk | grep -E "disk|part" || true
	exit 1
fi

# Create mountpoint
mkdir -p "$MOUNTPOINT"

# Cleanup function
cleanup() {
	log_info "Cleaning up..."
	set +e
	
	# Unmount special filesystems first
	for mount in "$MOUNTPOINT"/{dev,proc,sys,run}; do
		if mountpoint -q "$mount" 2>/dev/null; then
			umount "$mount" 2>/dev/null || true
		fi
	done
	
	# Unmount main partition
	if mountpoint -q "$MOUNTPOINT" 2>/dev/null; then
		umount "$MOUNTPOINT" 2>/dev/null || umount -l "$MOUNTPOINT" 2>/dev/null || true
	fi
	
	set -e
}

# Set up cleanup on exit
trap cleanup EXIT

log_step "1/3" "Mounting NixOS partition"
if ! mount "$TARGET_PARTITION" "$MOUNTPOINT"; then
	log_error "Failed to mount $TARGET_PARTITION"
	exit 1
fi
log_info "Mounted $TARGET_PARTITION to $MOUNTPOINT"

# Mount special filesystems needed for proper operation
mount --bind /dev "$MOUNTPOINT/dev" 2>/dev/null || true
mount --bind /proc "$MOUNTPOINT/proc" 2>/dev/null || true
mount --bind /sys "$MOUNTPOINT/sys" 2>/dev/null || true
mount --bind /run "$MOUNTPOINT/run" 2>/dev/null || true

# Check if this looks like a NixOS system
if [ ! -d "$MOUNTPOINT/nix" ] || [ ! -d "$MOUNTPOINT/etc/nixos" ]; then
	log_error "This doesn't appear to be a NixOS installation"
	log_error "Expected directories: /nix and /etc/nixos"
	exit 1
fi

log_step "2/3" "Listing available system generations"
PROFILE_DIR="$MOUNTPOINT/nix/var/nix/profiles"

# Get current generation
CURRENT_LINK="$PROFILE_DIR/system"
if [ -L "$CURRENT_LINK" ]; then
	CURRENT_GEN=$(basename "$(readlink "$CURRENT_LINK")")
	log_info "Current generation: $CURRENT_GEN"
else
	log_warn "Could not determine current generation"
fi

# List all available generations
log_info "Available generations:"
for link in "$PROFILE_DIR"/system-*-link; do
	if [ -L "$link" ]; then
		gen_num=$(basename "$link" | sed 's/system-\([0-9]*\)-link/\1/')
		target=$(readlink "$link")
		if [ "$(basename "$link")" = "$CURRENT_GEN" ]; then
			log_info "  * $gen_num (current) -> $target"
		else
			log_info "    $gen_num -> $target"
		fi
	fi
done

log_step "3/3" "Rolling back to previous generation"

# Find the previous generation
PREV_GEN=""
CURRENT_GEN_NUM=$(echo "$CURRENT_GEN" | sed 's/system-\([0-9]*\)-link/\1/')

# Look for the generation before the current one
for ((i=CURRENT_GEN_NUM-1; i>=34; i--)); do
	if [ -L "$PROFILE_DIR/system-$i-link" ]; then
		PREV_GEN="$i"
		break
	fi
done

if [ -z "$PREV_GEN" ]; then
	log_error "No previous generation found"
	exit 1
fi

log_info "Rolling back from generation $CURRENT_GEN_NUM to $PREV_GEN"

# Backup current system link
cp -a "$CURRENT_LINK" "$CURRENT_LINK.backup.$(date +%s)"

# Update the system symlink
cd "$PROFILE_DIR"
ln -sfn "system-$PREV_GEN-link" system
cd - > /dev/null

# Verify the change
NEW_GEN=$(basename "$(readlink "$CURRENT_LINK")")
if [ "$NEW_GEN" = "system-$PREV_GEN-link" ]; then
	log_success "Successfully rolled back to generation $PREV_GEN"
	log_info "The system will boot with generation $PREV_GEN on next restart"
	
	# Also update boot symlink if it exists
	if [ -L "$MOUNTPOINT/boot/system" ]; then
		ln -sfn "system-$PREV_GEN-link" "$MOUNTPOINT/boot/system"
		log_info "Updated boot symlink"
	fi
else
	log_error "Failed to update system symlink"
	exit 1
fi

log_info "Rollback complete. Reboot the system to use the previous generation."