#!/usr/bin/env bash

# Setup NixOS Config Script
#
# Purpose: Configure /etc/nixos for nixos-rebuild operations
# Dependencies: mkdir, nixos-generate-config, mv, ln
# Related: setup-helpers.nix, networking.nix
#
# This script:
# - Configures /etc/nixos for nixos-rebuild operations
# - Generates hardware configuration if missing
# - Creates symlinks to user's flake configuration

set -Eeuo pipefail

if [[ $EUID -ne 0 ]]; then
	echo "This script must be run as root."
	exit 1
fi

# Function to find nixos-config directory across all users
find_nixos_config() {
	local found_path=""
	# Search in all home directories for nixos-config
	for home_dir in /home/*; do
		if [[ -d "${home_dir}/nixos-config" ]] && [[ -f "${home_dir}/nixos-config/flake.nix" ]]; then
			found_path="${home_dir}/nixos-config"
			echo "[setup_nixos_config] Found nixos-config at: ${found_path}" >&2
			break
		fi
	done
	echo "$found_path"
}

# Try to read the profile from selected-profile.nix in the found nixos-config
# First, find where nixos-config is located
NIXOS_CONFIG_PATH=$(find_nixos_config)

if [[ -n "$NIXOS_CONFIG_PATH" ]] && [[ -f "${NIXOS_CONFIG_PATH}/shimboot_config/selected-profile.nix" ]]; then
	PROFILE=$(cat "${NIXOS_CONFIG_PATH}/shimboot_config/selected-profile.nix" 2>/dev/null || echo "default")
	echo "[setup_nixos_config] Using profile from selected-profile.nix: ${PROFILE}"
else
	# Fallback: try to read from current directory if running from nixos-config
	PROFILE=$(cat ./shimboot_config/selected-profile.nix 2>/dev/null || echo "default")
	echo "[setup_nixos_config] Using profile (fallback): ${PROFILE}"
fi

# Get username from the profile's user-config.nix
# Use NIXOS_CONFIG_PATH if discovered, otherwise fall back to relative path
if [[ -n "$NIXOS_CONFIG_PATH" ]]; then
	USERNAME=$(nix eval --raw --impure --expr "(import ${NIXOS_CONFIG_PATH}/shimboot_config/profiles/${PROFILE}/user-config.nix {}).user.username" 2>/dev/null || echo "${USER}")
else
	USERNAME=$(nix eval --raw --impure --expr "(import ./shimboot_config/profiles/${PROFILE}/user-config.nix {}).user.username" 2>/dev/null || echo "${USER}")
fi
echo "[setup_nixos_config] Username from profile: ${USERNAME}"

# If nixos-config wasn't found, check the expected path for the current profile
if [[ -z "$NIXOS_CONFIG_PATH" ]]; then
	NIXOS_CONFIG_PATH="/home/${USERNAME}/nixos-config"
	echo "[setup_nixos_config] Expected nixos-config path: ${NIXOS_CONFIG_PATH}"
fi

echo "[setup_nixos_config] Configuring /etc/nixos for nixos-rebuild..."
mkdir -p /etc/nixos

# Generate hardware config if missing
if [[ ! -f /etc/nixos/hardware-configuration.nix ]]; then
	echo "[setup_nixos_config] Generating hardware-configuration.nix..."
	echo "Command: nixos-generate-config --show-hardware-config > /etc/nixos/hardware-configuration.nix"
	nixos-generate-config --show-hardware-config >/etc/nixos/hardware-configuration.nix
fi

# Check if user's config exists (should be cloned by assemble-final.sh)
if [[ -d "${NIXOS_CONFIG_PATH}" ]] && [[ -f "${NIXOS_CONFIG_PATH}/flake.nix" ]]; then
	echo "[setup_nixos_config] ✓ Found nixos-config at ${NIXOS_CONFIG_PATH}"

	# Backup existing /etc/nixos files
	for file in configuration.nix flake.nix; do
		if [[ -f "/etc/nixos/${file}" ]] && [[ ! -L "/etc/nixos/${file}" ]]; then
			echo "[setup_nixos_config] Backing up /etc/nixos/${file} → ${file}.bak"
			echo "Command: mv \"/etc/nixos/${file}\" \"/etc/nixos/${file}.bak\""
			mv "/etc/nixos/${file}" "/etc/nixos/${file}.bak"
		fi
	done

	# Create symlink to user's flake
	echo "Command: ln -sf \"${NIXOS_CONFIG_PATH}/flake.nix\" /etc/nixos/flake.nix"
	ln -sf "${NIXOS_CONFIG_PATH}/flake.nix" /etc/nixos/flake.nix

	echo
	echo "[setup_nixos_config] ✓ Linked to nixos-shimboot repository"
	echo
	HOSTNAME_VALUE=$(hostname)
	echo "To rebuild:"
	echo "  cd ${NIXOS_CONFIG_PATH}"
	echo "  sudo nixos-rebuild switch --flake .#${HOSTNAME_VALUE}"
	echo
	echo "Available configurations:"
	echo "  • ${HOSTNAME_VALUE}-minimal (minimal system configuration)"
	echo "  • ${HOSTNAME_VALUE} (full system configuration)"
	echo "  • nixos-shimboot (generic shimboot configuration)"
	echo "  • raw-efi-system (EFI system only)"
	echo
	echo "Default: ${HOSTNAME_VALUE}"
	echo "Tip: 'minimal' variant uses only base modules (no desktop environment)"
else
	echo "[setup_nixos_config] ✗ nixos-config not found at ${NIXOS_CONFIG_PATH}"
	echo
	echo "The nixos-shimboot repository should be cloned by assemble-final.sh to:"
	echo "  ${NIXOS_CONFIG_PATH}"
	echo
	echo "This repository contains the NixOS configuration for shimboot."
	echo "Please ensure assemble-final.sh has cloned the repository correctly."
	echo
	echo "If the repository exists elsewhere, you can create a symlink:"
	echo "  sudo ln -sf /path/to/nixos-shimboot/flake.nix /etc/nixos/flake.nix"
	exit 1
fi

echo
echo "[setup_nixos_config] Done."
