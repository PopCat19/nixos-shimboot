#!/usr/bin/env bash

# Migrate Hostname Script
#
# Purpose: Handle hostname changes while preserving old hostname state
# Dependencies: coreutils, hostnamectl
# Related: helpers.nix, networking.nix
#
# This script:
# - Tracks previous hostname in state file
# - Detects hostname configuration changes
# - Applies new hostname if changed
# - Preserves old hostname in backup state

set -Eeuo pipefail

STATE_DIR="/var/lib/shimboot-migration"
STATE_FILE="${STATE_DIR}/hostname.state"
BACKUP_FILE="${STATE_DIR}/hostname.backup"

# New hostname is passed as first argument
NEW_HOSTNAME="${1:-}"

# Skip if no target hostname specified
if [[ -z "$NEW_HOSTNAME" ]]; then
	echo "[migrate-hostname] No target hostname specified, skipping."
	exit 0
fi

# Ensure state directory exists
mkdir -p "$STATE_DIR"

# Get current system hostname
CURRENT_HOSTNAME=$(hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || echo "")

# Read previous hostname from state file if exists
PREVIOUS_HOSTNAME=""
if [[ -f "$STATE_FILE" ]]; then
	PREVIOUS_HOSTNAME=$(cat "$STATE_FILE" 2>/dev/null || echo "")
fi

echo "[migrate-hostname] Current system hostname: ${CURRENT_HOSTNAME}"
echo "[migrate-hostname] Previous stored hostname: ${PREVIOUS_HOSTNAME:-none}"
echo "[migrate-hostname] New configured hostname: ${NEW_HOSTNAME}"

# If state file doesn't exist, this is first run
if [[ ! -f "$STATE_FILE" ]]; then
	echo "[migrate-hostname] First run, initializing state file..."
	echo "$NEW_HOSTNAME" > "$STATE_FILE"

	# If current hostname differs from new, update it
	if [[ "$CURRENT_HOSTNAME" != "$NEW_HOSTNAME" ]]; then
		echo "[migrate-hostname] Updating hostname from '${CURRENT_HOSTNAME}' to '${NEW_HOSTNAME}'"
		hostnamectl set-hostname "$NEW_HOSTNAME" 2>/dev/null || {
			echo "[migrate-hostname] Warning: Failed to set hostname via hostnamectl"
			echo "$NEW_HOSTNAME" > /etc/hostname
		}
	fi
	exit 0
fi

# State file exists - check if hostname changed in config
if [[ "$PREVIOUS_HOSTNAME" == "$NEW_HOSTNAME" ]]; then
	echo "[migrate-hostname] Hostname unchanged in config ('${NEW_HOSTNAME}'), no migration needed."

	# Still ensure system hostname matches
	if [[ "$CURRENT_HOSTNAME" != "$NEW_HOSTNAME" ]]; then
		echo "[migrate-hostname] Correcting system hostname to match config..."
		hostnamectl set-hostname "$NEW_HOSTNAME" 2>/dev/null || {
			echo "[migrate-hostname] Warning: Failed to set hostname via hostnamectl"
			echo "$NEW_HOSTNAME" > /etc/hostname
		}
	fi
	exit 0
fi

# Hostname changed in config - perform migration
echo "[migrate-hostname] Hostname change detected: '${PREVIOUS_HOSTNAME}' -> '${NEW_HOSTNAME}'"

# Backup old hostname
echo "$PREVIOUS_HOSTNAME" > "$BACKUP_FILE"
echo "[migrate-hostname] Backed up previous hostname to ${BACKUP_FILE}"

# Update state file with new hostname
echo "$NEW_HOSTNAME" > "$STATE_FILE"

# Apply new hostname
echo "[migrate-hostname] Applying new hostname: ${NEW_HOSTNAME}"
hostnamectl set-hostname "$NEW_HOSTNAME" 2>/dev/null || {
	echo "[migrate-hostname] Warning: Failed to set hostname via hostnamectl"
	echo "$NEW_HOSTNAME" > /etc/hostname
}

echo "[migrate-hostname] Hostname migration complete."
echo "[migrate-hostname]   Previous: ${PREVIOUS_HOSTNAME}"
echo "[migrate-hostname]   New: ${NEW_HOSTNAME}"
