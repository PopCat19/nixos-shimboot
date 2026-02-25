#!/usr/bin/env bash

# Migrate Username Script
#
# Purpose: Handle username changes while preserving user data and home directory
# Dependencies: coreutils, shadow, findutils
# Related: helpers.nix, users.nix
#
# This script:
# - Tracks previous username in state file
# - Detects username configuration changes
# - Migrates home directory and user data if changed
# - Preserves old username backup for rollback

set -Eeuo pipefail

STATE_DIR="/var/lib/shimboot-migration"
STATE_FILE="${STATE_DIR}/username.state"
BACKUP_FILE="${STATE_DIR}/username.backup"

# New username is passed as first argument
NEW_USERNAME="${1:-}"

# Skip if no target username specified
if [[ -z "$NEW_USERNAME" ]]; then
	echo "[migrate-username] No target username specified, skipping."
	exit 0
fi

# Ensure state directory exists
mkdir -p "$STATE_DIR"

# Read previous username from state file if exists
PREVIOUS_USERNAME=""
if [[ -f "$STATE_FILE" ]]; then
	PREVIOUS_USERNAME=$(cat "$STATE_FILE" 2>/dev/null || echo "")
fi

echo "[migrate-username] Previous stored username: ${PREVIOUS_USERNAME:-none}"
echo "[migrate-username] New configured username: ${NEW_USERNAME}"

# If state file doesn't exist, this is first run
if [[ ! -f "$STATE_FILE" ]]; then
	echo "[migrate-username] First run, initializing state file..."
	echo "$NEW_USERNAME" > "$STATE_FILE"

	# Check if user already exists with different name
	EXISTING_USER=$(ls /home 2>/dev/null | grep -v '^lost+found$' | head -1 || true)
	if [[ -n "$EXISTING_USER" ]] && [[ "$EXISTING_USER" != "$NEW_USERNAME" ]]; then
		echo "[migrate-username] Found existing user '${EXISTING_USER}', but no migration state."
		echo "[migrate-username] Preserving existing user. Run manual migration if needed."
		# Store existing user as previous to prevent auto-migration
		echo "$EXISTING_USER" > "$STATE_FILE"
	fi
	exit 0
fi

# State file exists - check if username changed in config
if [[ "$PREVIOUS_USERNAME" == "$NEW_USERNAME" ]]; then
	echo "[migrate-username] Username unchanged in config ('${NEW_USERNAME}'), no migration needed."
	exit 0
fi

# Username changed in config - perform migration
echo "[migrate-username] Username change detected: '${PREVIOUS_USERNAME}' -> '${NEW_USERNAME}'"

# Check if previous user exists
if ! id "$PREVIOUS_USERNAME" &>/dev/null; then
	echo "[migrate-username] Previous user '${PREVIOUS_USERNAME}' does not exist."
	echo "[migrate-username] Creating new user '${NEW_USERNAME}' without migration."
	echo "$NEW_USERNAME" > "$STATE_FILE"
	exit 0
fi

# Check if new user already exists
if id "$NEW_USERNAME" &>/dev/null; then
	echo "[migrate-username] Warning: New user '${NEW_USERNAME}' already exists."
	echo "[migrate-username] Skipping migration to avoid data loss."
	echo "[migrate-username] Manual intervention required."
	exit 0
fi

# Backup old username
echo "$PREVIOUS_USERNAME" > "$BACKUP_FILE"
echo "[migrate-username] Backed up previous username to ${BACKUP_FILE}"

# Get previous user's info
OLD_HOME=$(getent passwd "$PREVIOUS_USERNAME" | cut -d: -f6)
OLD_UID=$(getent passwd "$PREVIOUS_USERNAME" | cut -d: -f3)
OLD_GID=$(getent passwd "$PREVIOUS_USERNAME" | cut -d: -f4)
OLD_GROUPS=$(id -Gn "$PREVIOUS_USERNAME" 2>/dev/null | tr ' ' ',' || echo "")

echo "[migrate-username] Old user info:"
echo "[migrate-username]   Username: ${PREVIOUS_USERNAME}"
echo "[migrate-username]   UID: ${OLD_UID}"
echo "[migrate-username]   GID: ${OLD_GID}"
echo "[migrate-username]   Home: ${OLD_HOME}"
echo "[migrate-username]   Groups: ${OLD_GROUPS}"

# Perform user rename
echo "[migrate-username] Renaming user '${PREVIOUS_USERNAME}' to '${NEW_USERNAME}'..."

# Rename user
usermod -l "$NEW_USERNAME" "$PREVIOUS_USERNAME" 2>/dev/null || {
	echo "[migrate-username] Error: Failed to rename user"
	exit 1
}

# Rename group if it exists with same name as old user
if getent group "$PREVIOUS_USERNAME" &>/dev/null; then
	groupmod -n "$NEW_USERNAME" "$PREVIOUS_USERNAME" 2>/dev/null || true
fi

# Move home directory if it exists and is at expected location
if [[ -d "$OLD_HOME" ]]; then
	NEW_HOME="/home/${NEW_USERNAME}"

	if [[ "$OLD_HOME" != "$NEW_HOME" ]]; then
		echo "[migrate-username] Moving home directory: ${OLD_HOME} -> ${NEW_HOME}"
		mv "$OLD_HOME" "$NEW_HOME"

		# Update home directory in passwd
		usermod -d "$NEW_HOME" "$NEW_USERNAME" 2>/dev/null || true
	fi

	# Update ownership
	chown -R "${NEW_USERNAME}:${NEW_USERNAME}" "$NEW_HOME" 2>/dev/null || true
fi

# Update state file with new username
echo "$NEW_USERNAME" > "$STATE_FILE"

echo "[migrate-username] Username migration complete."
echo "[migrate-username]   Previous: ${PREVIOUS_USERNAME}"
echo "[migrate-username]   New: ${NEW_USERNAME}"
echo "[migrate-username]   Home: ${NEW_HOME:-/home/${NEW_USERNAME}}"
echo ""
echo "[migrate-username] Note: A system rebuild may be required to apply all changes."
