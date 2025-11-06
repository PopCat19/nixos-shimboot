#!/usr/bin/env bash

# Stage 2 Inspection Script
#
# Purpose: Inspect and manually edit NixOS stage 2 components (systemd, services)
# Dependencies: mount, umount, nano/vim
# Related: assemble-final.sh
#
# This script allows inspection and manual editing of stage 2 boot components.

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

# === Configuration ===
TARGET_PARTITION="${1:-}"
MOUNTPOINT="/mnt/nixos-rollback"
EDITOR="${EDITOR:-nano}"

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
	log_info "Default: /dev/sde5"
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
	if mountpoint -q "$MOUNTPOINT" 2>/dev/null; then
		umount "$MOUNTPOINT" 2>/dev/null || umount -l "$MOUNTPOINT" 2>/dev/null || true
	fi
	set -e
}

# Set up cleanup on exit
trap cleanup EXIT

log_step "1/3" "Mounting partition"
if ! mount "$TARGET_PARTITION" "$MOUNTPOINT"; then
	log_error "Failed to mount $TARGET_PARTITION"
	exit 1
fi
log_info "Mounted root partition: $TARGET_PARTITION"

log_step "2/3" "Finding current generation"
PROFILE_DIR="$MOUNTPOINT/nix/var/nix/profiles"

if [ -L "$PROFILE_DIR/system" ]; then
	CURRENT_GEN=$(basename "$(readlink "$PROFILE_DIR/system")")
	CURRENT_GEN_NUM=$(echo "$CURRENT_GEN" | sed 's/system-\([0-9]*\)-link/\1/')
	CURRENT_TARGET=$(readlink "$PROFILE_DIR/system")
	# Get the actual store path
	if [ -L "$PROFILE_DIR/system" ]; then
		CURRENT_TARGET=$(readlink -f "$PROFILE_DIR/system")
	fi
	log_info "Current generation: ${ANSI_CYAN}$CURRENT_GEN_NUM${ANSI_CLEAR}"
	log_info "Store path: $CURRENT_TARGET"
else
	log_error "Could not determine current generation"
	exit 1
fi

# Check init script
log_info "Checking init script configuration:"
if [ -f "$MOUNTPOINT/init" ]; then
	INIT_CONFIG=$(grep "^systemConfig=" "$MOUNTPOINT/init" | cut -d'=' -f2)
	log_info "  Init systemConfig: $INIT_CONFIG"
	
	INIT_SYSTEMD=$(grep "exec.*systemd" "$MOUNTPOINT/init" | grep -o "/nix/store/[^[:space:]]*systemd")
	log_info "  Init systemd path: $INIT_SYSTEMD"
else
	log_warn "No init script found"
fi

log_step "3/3" "Stage 2 inspection menu"

while true; do
	echo
	printf "${ANSI_BOLD}Stage 2 Inspection Menu${ANSI_CLEAR}\n"
	echo "1) List systemd binaries in current generation"
	echo "2) Inspect systemd service files"
	echo "3) Check bwrap-related configurations"
	echo "4) Inspect activation script"
	echo "5) Edit init script manually"
	echo "6) Browse generation store paths"
	echo "7) Switch to different generation"
	echo "8) Exit"
	echo
	read -p "Select option [1-7]: " CHOICE
	
	case "$CHOICE" in
		1)
			echo
			log_info "Systemd binaries in $CURRENT_TARGET:"
			if [ -d "$MOUNTPOINT$CURRENT_TARGET/lib/systemd" ]; then
				ls -la "$MOUNTPOINT$CURRENT_TARGET/lib/systemd/" | head -20
			else
				log_warn "Systemd directory not found"
			fi
			;;
		2)
			echo
			log_info "Systemd service files:"
			if [ -d "$MOUNTPOINT$CURRENT_TARGET/etc/systemd" ]; then
				echo "Available service directories:"
				find "$MOUNTPOINT$CURRENT_TARGET/etc/systemd" -type d | head -10
				echo
				read -p "Enter service name to inspect (or blank to list): " SERVICE
				if [ -n "$SERVICE" ]; then
					find "$MOUNTPOINT$CURRENT_TARGET/etc/systemd" -name "*${SERVICE}*.service" -exec echo "=== {} ===" \; -exec cat {} \;
				else
					find "$MOUNTPOINT$CURRENT_TARGET/etc/systemd" -name "*.service" | head -20
				fi
			else
				log_warn "Systemd service directory not found"
			fi
			;;
		3)
			echo
			log_info "Bwrap-related configurations:"
			# Check for bwrap in systemd units
			if [ -d "$MOUNTPOINT$CURRENT_TARGET/etc/systemd" ]; then
				grep -r "bwrap" "$MOUNTPOINT$CURRENT_TARGET/etc/systemd" 2>/dev/null || log_warn "No bwrap references found in systemd units"
			fi
			# Check for bwrap binaries
			if [ -d "$MOUNTPOINT$CURRENT_TARGET" ]; then
				find "$MOUNTPOINT$CURRENT_TARGET" -name "*bwrap*" 2>/dev/null || log_warn "No bwrap binaries found"
			fi
			# Check activation script for bwrap
			if [ -f "$MOUNTPOINT$CURRENT_TARGET/activate" ]; then
				log_info "Checking activation script for bwrap:"
				grep -n "bwrap" "$MOUNTPOINT$CURRENT_TARGET/activate" 2>/dev/null || log_warn "No bwrap in activation script"
			fi
			;;
		4)
			echo
			log_info "Inspecting activation script..."
			if [ -f "$MOUNTPOINT$CURRENT_TARGET/activate" ]; then
				echo "Activation script location: $MOUNTPOINT$CURRENT_TARGET/activate"
				echo
				echo "=== First 50 lines ==="
				head -50 "$MOUNTPOINT$CURRENT_TARGET/activate"
				echo
				echo "=== Lines containing 'bwrap' ==="
				grep -n "bwrap" "$MOUNTPOINT$CURRENT_TARGET/activate" 2>/dev/null || echo "No bwrap found"
				echo
				echo "=== Lines containing '/etc' setup ==="
				grep -n "/etc" "$MOUNTPOINT$CURRENT_TARGET/activate" | head -20
				echo
				read -p "Edit activation script? [y/N] " EDIT_ACT
				if [[ "$EDIT_ACT" =~ ^[yY] ]]; then
					$EDITOR "$MOUNTPOINT$CURRENT_TARGET/activate"
					log_info "Activation script edited"
				fi
			else
				log_error "Activation script not found at $MOUNTPOINT$CURRENT_TARGET/activate"
			fi
			;;
		5)
			echo
			log_info "Editing init script..."
			if [ -f "$MOUNTPOINT/init" ]; then
				$EDITOR "$MOUNTPOINT/init"
				log_info "Init script edited"
			else
				log_error "No init script found"
			fi
			;;
		6)
			echo
			log_info "Store contents of generation $CURRENT_GEN_NUM:"
			if [ -d "$MOUNTPOINT$CURRENT_TARGET" ]; then
				ls -la "$MOUNTPOINT$CURRENT_TARGET" | head -30
			fi
			;;
		7)
			echo
			log_info "Available generations:"
			declare -a GENERATIONS
			for link in "$PROFILE_DIR"/system-*-link; do
				if [ -L "$link" ]; then
					gen_num=$(basename "$link" | sed 's/system-\([0-9]*\)-link/\1/')
					GENERATIONS+=("$gen_num")
				fi
			done
			
			IFS=$'\n' GENERATIONS=($(sort -n <<<"${GENERATIONS[*]}"))
			unset IFS
			
			for gen in "${GENERATIONS[@]}"; do
				if [ "$gen" = "$CURRENT_GEN_NUM" ]; then
					printf "  * ${ANSI_CYAN}Generation %s (current)${ANSI_CLEAR}\n" "$gen"
				else
					printf "    Generation %s\n" "$gen"
				fi
			done
			
			read -p "Enter generation number to switch to: " NEW_GEN
			if [[ "$NEW_GEN" =~ ^[0-9]+$ ]] && [ -L "$PROFILE_DIR/system-$NEW_GEN-link" ]; then
				# Update system profile
				ln -sfn "system-$NEW_GEN-link" "$PROFILE_DIR/system"
				CURRENT_TARGET=$(readlink "$PROFILE_DIR/system")
				log_success "Switched to generation $NEW_GEN"
				log_info "New store path: $CURRENT_TARGET"
			else
				log_error "Invalid generation number"
			fi
			;;
		8)
			log_info "Exiting..."
			exit 0
			;;
		*)
			log_error "Invalid option"
			;;
	esac
	
	echo
	read -p "Press Enter to continue..."
done