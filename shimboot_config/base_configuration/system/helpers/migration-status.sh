#!/usr/bin/env bash

# Migration Status Script
#
# Purpose: Display current migration state and history
# Dependencies: coreutils
# Related: helpers.nix, migrate-hostname.sh, migrate-username.sh
#
# This script:
# - Shows current and previous hostname/username
# - Displays backup state if available
# - Provides rollback commands if migration occurred

set -Eeuo pipefail

STATE_DIR="/var/lib/shimboot-migration"

echo "=== Shimboot Migration Status ==="
echo ""

# Hostname status
echo "--- Hostname ---"
if [[ -f "${STATE_DIR}/hostname.state" ]]; then
	CURRENT_STATE=$(cat "${STATE_DIR}/hostname.state")
	SYSTEM_HOSTNAME=$(hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || echo "unknown")

	echo "  Configured: ${CURRENT_STATE}"
	echo "  System: ${SYSTEM_HOSTNAME}"

	if [[ -f "${STATE_DIR}/hostname.backup" ]]; then
		BACKUP=$(cat "${STATE_DIR}/hostname.backup")
		echo "  Previous: ${BACKUP}"
		echo ""
		echo "  Rollback: sudo hostnamectl set-hostname '${BACKUP}'"
	fi
else
	echo "  No migration state found (first run pending)"
fi
echo ""

# Username status
echo "--- Username ---"
if [[ -f "${STATE_DIR}/username.state" ]]; then
	CURRENT_STATE=$(cat "${STATE_DIR}/username.state")

	echo "  Configured: ${CURRENT_STATE}"

	# Check if user exists
	if id "$CURRENT_STATE" &>/dev/null; then
		echo "  User exists: yes"
		USER_HOME=$(getent passwd "$CURRENT_STATE" | cut -d: -f6)
		echo "  Home: ${USER_HOME}"
	else
		echo "  User exists: no"
	fi

	if [[ -f "${STATE_DIR}/username.backup" ]]; then
		BACKUP=$(cat "${STATE_DIR}/username.backup")
		echo "  Previous: ${BACKUP}"
		echo ""
		echo "  Note: Username rollback requires manual intervention"
		echo "  See: migrate-username.sh for details"
	fi
else
	echo "  No migration state found (first run pending)"
fi
echo ""

# NixOS config status
echo "--- NixOS Config ---"
NIXOS_CONFIG=""
for home_dir in /home/*; do
	if [[ -d "${home_dir}/nixos-config" ]] && [[ -f "${home_dir}/nixos-config/flake.nix" ]]; then
		NIXOS_CONFIG="${home_dir}/nixos-config"
		break
	fi
done

if [[ -n "$NIXOS_CONFIG" ]]; then
	echo "  Location: ${NIXOS_CONFIG}"
	if [[ -L "/etc/nixos/flake.nix" ]]; then
		LINK_TARGET=$(readlink -f /etc/nixos/flake.nix)
		echo "  Linked: ${LINK_TARGET}"
	fi
else
	echo "  No nixos-config found in home directories"
fi
echo ""

echo "=== End Migration Status ==="
