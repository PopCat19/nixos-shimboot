#!/usr/bin/env bash

# Full Rollback Script
#
# Purpose: Rollback both NixOS system generation and init script
# Dependencies: mount, umount, ln, cp
# Related: assemble-final.sh
#
# This script rolls back both the system profile and the init script
# in the bootloader partition to fully revert the system.

set -euo pipefail

# === Colors & Logging ===
ANSI_CLEAR='\033[0m'
ANSI_BOLD='\033[1m'
ANSI_GREEN='\033[1;32m'
ANSI_BLUE='\033[1;34m'
ANSI_YELLOW='\033[1;33m'
ANSI_RED='\033[1;31m'
ANSI_CYAN='\033[1;36m'

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
TARGET_PARTITION="${1:-/dev/sdd5}"
MOUNTPOINT="/mnt/nixos-rollback"

# Check if running as root
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
	log_error "This script must be run as root"
	log_info "Usage: sudo $0 [root_partition]"
	log_info "Default: /dev/sdd5"
	exit 1
fi

# Validate partition exists
if [ ! -b "$TARGET_PARTITION" ]; then
	log_error "Partition does not exist: $TARGET_PARTITION"
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
	
	# Unmount special filesystems
	for mount in "$MOUNTPOINT"/{dev,proc,sys,run}; do
		if mountpoint -q "$mount" 2>/dev/null; then
			umount "$mount" 2>/dev/null || true
		fi
	done
	
	# Unmount partition
	if mountpoint -q "$MOUNTPOINT" 2>/dev/null; then
		umount "$MOUNTPOINT" 2>/dev/null || umount -l "$MOUNTPOINT" 2>/dev/null || true
	fi
	
	set -e
}

# Set up cleanup on exit
trap cleanup EXIT

log_step "1/4" "Mounting partition"
if ! mount "$TARGET_PARTITION" "$MOUNTPOINT"; then
	log_error "Failed to mount $TARGET_PARTITION"
	exit 1
fi
log_info "Mounted root partition: $TARGET_PARTITION"

# Mount special filesystems
mount --bind /dev "$MOUNTPOINT/dev" 2>/dev/null || true
mount --bind /proc "$MOUNTPOINT/proc" 2>/dev/null || true
mount --bind /sys "$MOUNTPOINT/sys" 2>/dev/null || true
mount --bind /run "$MOUNTPOINT/run" 2>/dev/null || true

log_step "2/5" "Listing available system generations"
PROFILE_DIR="$MOUNTPOINT/nix/var/nix/profiles"

# Get current generation
CURRENT_LINK="$PROFILE_DIR/system"
if [ -L "$CURRENT_LINK" ]; then
	CURRENT_GEN=$(basename "$(readlink "$CURRENT_LINK")")
	CURRENT_GEN_NUM=$(echo "$CURRENT_GEN" | sed 's/system-\([0-9]*\)-link/\1/')
	log_info "Current generation: ${ANSI_CYAN}$CURRENT_GEN_NUM${ANSI_CLEAR}"
else
	log_warn "Could not determine current generation"
fi

# Collect available generations
declare -a GENERATIONS
declare -a GEN_TARGETS

for link in "$PROFILE_DIR"/system-*-link; do
	if [ -L "$link" ]; then
		gen_num=$(basename "$link" | sed 's/system-\([0-9]*\)-link/\1/')
		target=$(readlink "$link")
		GENERATIONS+=("$gen_num")
		GEN_TARGETS+=("$target")
	fi
done

# Sort generations numerically
IFS=$'\n' GENERATIONS=($(sort -n <<<"${GENERATIONS[*]}"))
unset IFS

# Display generations with numbers
log_info "Available generations:"
for i in "${!GENERATIONS[@]}"; do
	gen_num="${GENERATIONS[$i]}"
	target="${GEN_TARGETS[$i]}"
	if [ "$gen_num" = "$CURRENT_GEN_NUM" ]; then
		printf "${ANSI_CYAN}  %d) Generation %d (current)${ANSI_CLEAR}\n" $((i+1)) "$gen_num"
	else
		printf "  %d) Generation %d\n" $((i+1)) "$gen_num"
	fi
done

log_step "3/4" "Select generation to rollback to"

# Prompt for selection
echo
read -p "Enter generation number (1-${#GENERATIONS[@]}) or press Enter for rollback to previous: " CHOICE

if [ -z "$CHOICE" ]; then
	# Default to previous generation
	SELECTED_GEN=""
	for ((i=${#GENERATIONS[@]}-1; i>=0; i--)); do
		if [ "${GENERATIONS[$i]}" = "$CURRENT_GEN_NUM" ]; then
			if [ $i -gt 0 ]; then
				SELECTED_GEN="${GENERATIONS[$((i-1))]}"
			fi
			break
		fi
	done
	
	if [ -z "$SELECTED_GEN" ]; then
		log_error "No previous generation found"
		exit 1
	fi
	log_info "Selected previous generation: $SELECTED_GEN"
else
	# Validate choice
	if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt ${#GENERATIONS[@]} ]; then
		log_error "Invalid selection: $CHOICE"
		exit 1
	fi
	
	SELECTED_GEN="${GENERATIONS[$((CHOICE-1))]}"
	log_info "Selected generation: $SELECTED_GEN"
fi

if [ "$SELECTED_GEN" = "$CURRENT_GEN_NUM" ]; then
	log_warn "Selected generation is the same as current. No changes needed."
	exit 0
fi

# Find the target store path for the selected generation
SELECTED_TARGET=""
for i in "${!GENERATIONS[@]}"; do
	if [ "${GENERATIONS[$i]}" = "$SELECTED_GEN" ]; then
		SELECTED_TARGET="${GEN_TARGETS[$i]}"
		break
	fi
done

if [ -z "$SELECTED_TARGET" ]; then
	log_error "Could not find target path for generation $SELECTED_GEN"
	exit 1
fi

log_step "4/4" "Rolling back system and init script"

# Confirm rollback
echo
read -p "Confirm rollback to generation $SELECTED_GEN? [y/N] " CONFIRM
if [[ ! "$CONFIRM" =~ ^[yY] ]]; then
	log_info "Rollback cancelled."
	exit 0
fi

# Backup current system link
cp -a "$CURRENT_LINK" "$CURRENT_LINK.backup.$(date +%s)"

# Update the system symlink
cd "$PROFILE_DIR"
ln -sfn "system-$SELECTED_GEN-link" system
cd - > /dev/null

# Verify the change
NEW_GEN=$(basename "$(readlink "$CURRENT_LINK")")
if [ "$NEW_GEN" = "system-$SELECTED_GEN-link" ]; then
	log_success "Successfully rolled back system profile to generation $SELECTED_GEN"
else
	log_error "Failed to update system symlink"
	exit 1
fi

# Update the init script in the rootfs
log_info "Updating init script in rootfs"

# Check if init exists in the selected generation
INIT_PATH="$MOUNTPOINT$SELECTED_TARGET/init"
if [ ! -f "$INIT_PATH" ]; then
	log_error "Init script not found at $INIT_PATH"
	exit 1
fi

# Backup current init
if [ -f "$MOUNTPOINT/init" ]; then
	cp -a "$MOUNTPOINT/init" "$MOUNTPOINT/init.backup.$(date +%s)"
	log_info "Backed up current init script"
fi

# Copy init from selected generation to rootfs
cp -a "$INIT_PATH" "$MOUNTPOINT/init"
log_success "Updated init script from generation $SELECTED_GEN"

# Verify init was copied
if [ -f "$MOUNTPOINT/init" ]; then
	log_info "Init script successfully updated"
	log_info "New init size: $(stat -c%s "$MOUNTPOINT/init" 2>/dev/null || echo "unknown") bytes"
else
	log_error "Failed to copy init script"
	exit 1
fi

log_success "Full rollback complete!"
log_info "Both system profile and init script have been rolled back to generation $SELECTED_GEN"
log_info "Reboot the system to use the rolled back configuration."