#!/usr/bin/env bash

# Fix Bwrap Regression Script
#
# Purpose: Fix the bwrap ENOENT regression in activation script
# Dependencies: mount, umount, sed
# Related: assemble-final.sh
#
# This script patches the activation script to handle missing bwrap gracefully.

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
	log_info "Default: /dev/sde5"
	exit 1
fi

# Validate partition exists
if [ ! -b "$TARGET_PARTITION" ]; then
	log_error "Partition does not exist: $TARGET_PARTITION"
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
	CURRENT_TARGET=$(readlink -f "$PROFILE_DIR/system")
	log_info "Current generation: $CURRENT_TARGET"
else
	log_error "Could not determine current generation"
	exit 1
fi

ACTIVATE_SCRIPT="$MOUNTPOINT$CURRENT_TARGET/activate"

if [ ! -f "$ACTIVATE_SCRIPT" ]; then
	log_error "Activation script not found: $ACTIVATE_SCRIPT"
	exit 1
fi

log_step "3/3" "Patching activation script"

# Backup the activation script
cp -a "$ACTIVATE_SCRIPT" "$ACTIVATE_SCRIPT.backup.$(date +%s)"
log_info "Backed up activation script"

# Check if the bwrap fix exists
if grep -q "fix-steam-bwrap" "$ACTIVATE_SCRIPT"; then
	log_info "Found bwrap fix snippet, patching..."
	
	# Create a temporary file with the patched version
	TMP_FILE=$(mktemp)
	
	# Patch the bwrap fix to check if the source exists
	awk '
	/^#### Activation script snippet fix-steam-bwrap:/ {
		print $0
		in_bwrap = 1
		next
	}
	in_bwrap && /^#### Activation script snippet/ {
		in_bwrap = 0
		print "#### Activation script snippet fix-steam-bwrap:"
		print "_localstatus=0"
		print "echo \"Checking for Steam bwrap copies...\""
		print ""
		print "if [ -d /home ]; then"
		print "  for USER_HOME in /home/*; do"
		print "    if [ -d \"$USER_HOME/.steam\" ]; then"
		print "      echo \"Fixing Steam bwrap copies for nixos-user...\""
		print "      # Find and fix all srt-bwrap binaries"
		print "      find \"$USER_HOME/.steam\" -name '\''srt-bwrap'\'' -type f 2>/dev/null | while read -r bwrap; do"
		print "        if [ -f \"$bwrap\" ]; then"
		print "          # Check if bwrap exists in wrappers or system"
		print "          if [ -f /run/wrappers/bin/bwrap ]; then"
		print "            cp /run/wrappers/bin/bwrap \"$bwrap\" 2>/dev/null || true"
		print "            chmod u+s \"$bwrap\" 2>/dev/null || true"
		print "            echo \"  ✓ Fixed: $bwrap\""
		print "          elif command -v bwrap >/dev/null 2>&1; then"
		print "            # Fallback to system bwrap"
		print "            cp $(command -v bwrap) \"$bwrap\" 2>/dev/null || true"
		print "            chmod u+s \"$bwrap\" 2>/dev/null || true"
		print "            echo \"  ✓ Fixed (system): $bwrap\""
		print "          else"
		print "            echo \"  ! Skipping: $bwrap (bwrap not found)\""
		print "          fi"
		print "        fi"
		print "      done"
		print "    fi"
		print "  done"
		print "fi"
		print ""
		print "if (( _localstatus > 0 )); then"
		print "  printf \"Activation script snippet '\''%s'\'' failed (%s)\\n\" \"fix-steam-bwrap\" \"$_localstatus\""
		print "fi"
		print ""
		print $0
		next
	}
	!in_bwrap { print }
	' "$ACTIVATE_SCRIPT" > "$TMP_FILE"
	
	# Replace the original with the patched version
	mv "$TMP_FILE" "$ACTIVATE_SCRIPT"
	chmod +x "$ACTIVATE_SCRIPT"
	
	log_success "Patched activation script to handle missing bwrap gracefully"
else
	log_warn "No bwrap fix snippet found in activation script"
fi

log_success "Bwrap regression fix complete!"
log_info "The activation script will now handle missing bwrap gracefully."
log_info "Reboot the system for changes to take effect."