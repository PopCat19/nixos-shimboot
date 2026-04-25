#!/usr/bin/env bash

# Migrate NixOS Config Script
#
# Purpose: Automatically migrate nixos-shimboot to current user's home directory
# Dependencies: coreutils, findutils
# Related: helpers.nix, users.nix
#
# This script:
# - Checks if nixos-shimboot exists in another user's home
# - Migrates it to the current profile user's home if missing
# - Updates ownership and permissions
# - Runs during system activation

set -Eeuo pipefail

# Target username is passed as first argument
TARGET_USER="${1:-}"
TARGET_HOME="/home/${TARGET_USER}"
TARGET_CONFIG="${TARGET_HOME}/nixos-shimboot"

# Skip if no target user specified
if [[ -z "$TARGET_USER" ]]; then
	echo "[migrate_nixos_shimboot] No target user specified, skipping migration."
	exit 0
fi

# Skip if target user doesn't exist
if ! id "$TARGET_USER" &>/dev/null; then
	echo "[migrate_nixos_shimboot] User $TARGET_USER doesn't exist yet, skipping."
	exit 0
fi

# If target config already exists, nothing to do
if [[ -d "$TARGET_CONFIG" ]] && [[ -f "${TARGET_CONFIG}/flake.nix" ]]; then
	echo "[migrate_nixos_shimboot] [OK] nixos-shimboot already exists at ${TARGET_CONFIG}"
	exit 0
fi

# Search for existing nixos-shimboot in other home directories
SOURCE_CONFIG=""
for home_dir in /home/*; do
	# Skip target user's home
	if [[ "$home_dir" == "$TARGET_HOME" ]]; then
		continue
	fi

	# Check for nixos-shimboot with flake.nix
	if [[ -d "${home_dir}/nixos-shimboot" ]] && [[ -f "${home_dir}/nixos-shimboot/flake.nix" ]]; then
		SOURCE_CONFIG="${home_dir}/nixos-shimboot"
		echo "[migrate_nixos_shimboot] Found existing nixos-shimboot at: ${SOURCE_CONFIG}"
		break
	fi
done

# If no source found, nothing to migrate
if [[ -z "$SOURCE_CONFIG" ]]; then
	echo "[migrate_nixos_shimboot] No existing nixos-shimboot found to migrate."
	exit 0
fi

# Perform migration
echo "[migrate_nixos_shimboot] Migrating nixos-shimboot from ${SOURCE_CONFIG} to ${TARGET_CONFIG}"

# Ensure target home exists
if [[ ! -d "$TARGET_HOME" ]]; then
	echo "[migrate_nixos_shimboot] Target home directory doesn't exist: ${TARGET_HOME}"
	exit 1
fi

# Move the config
mv "$SOURCE_CONFIG" "$TARGET_CONFIG"

# Fix ownership
chown -R "${TARGET_USER}:users" "$TARGET_CONFIG"

echo "[migrate_nixos_shimboot] [OK] Successfully migrated nixos-shimboot to ${TARGET_CONFIG}"
echo "[migrate_nixos_shimboot]   Old location: ${SOURCE_CONFIG} (removed)"
echo "[migrate_nixos_shimboot]   New location: ${TARGET_CONFIG}"
