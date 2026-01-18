#!/usr/bin/env fish

# Setup NixOS Config Function
#
# Purpose: Configure /etc/nixos for nixos-rebuild operations
# Dependencies: mkdir, nixos-generate-config, mv, ln
# Related: setup-helpers.nix, networking.nix
#
# This function:
# - Configures /etc/nixos for nixos-rebuild operations
# - Generates hardware configuration if missing
# - Creates symlinks to user's flake configuration

function setup_nixos_config
    set -euo pipefail

    if test (id -u) -ne 0
        echo "This script must be run as root."
        exit 1
    end

    set -l USERNAME "$USER"
    set -l NIXOS_CONFIG_PATH "/home/$USERNAME/nixos-config"

    echo "[setup_nixos_config] Configuring /etc/nixos for nixos-rebuild..."
    mkdir -p /etc/nixos

    # Generate hardware config if missing
    if not test -f /etc/nixos/hardware-configuration.nix
        echo "[setup_nixos_config] Generating hardware-configuration.nix..."
        echo "Command: nixos-generate-config --show-hardware-config > /etc/nixos/hardware-configuration.nix"
        nixos-generate-config --show-hardware-config > /etc/nixos/hardware-configuration.nix
    end

    # Check if user's config exists (should be cloned by assemble-final.sh)
    if test -d "$NIXOS_CONFIG_PATH"; and test -f "$NIXOS_CONFIG_PATH/flake.nix"
        echo "[setup_nixos_config] ✓ Found nixos-config at $NIXOS_CONFIG_PATH"

        # Backup existing /etc/nixos files
        for file in configuration.nix flake.nix
            if test -f "/etc/nixos/$file"; and not test -L "/etc/nixos/$file"
                echo "[setup_nixos_config] Backing up /etc/nixos/$file → $file.bak"
                echo "Command: mv \"/etc/nixos/$file\" \"/etc/nixos/$file.bak\""
                mv "/etc/nixos/$file" "/etc/nixos/$file.bak"
            end
        end

        # Create symlink to user's flake
        echo "Command: ln -sf \"$NIXOS_CONFIG_PATH/flake.nix\" /etc/nixos/flake.nix"
        ln -sf "$NIXOS_CONFIG_PATH/flake.nix" /etc/nixos/flake.nix

        echo
        echo "[setup_nixos_config] ✓ Linked to nixos-shimboot repository"
        echo
        set -l HOSTNAME_VALUE (set -q HOSTNAME; and echo "$HOSTNAME"; or hostname)
        echo "To rebuild:"
        echo "  cd $NIXOS_CONFIG_PATH"
        echo "  sudo nixos-rebuild switch --flake .#$HOSTNAME_VALUE"
        echo
        echo "Available configurations:"
        echo "  • $HOSTNAME_VALUE-minimal (minimal system configuration)"
        echo "  • $HOSTNAME_VALUE (full system configuration)"
        echo "  • nixos-shimboot (generic shimboot configuration)"
        echo "  • raw-efi-system (EFI system only)"
        echo
        echo "Default: $HOSTNAME_VALUE"
        echo "Tip: 'minimal' variant uses only base modules (no desktop environment)"
    else
        echo "[setup_nixos_config] ✗ nixos-config not found at $NIXOS_CONFIG_PATH"
        echo
        echo "The nixos-shimboot repository should be cloned by assemble-final.sh to:"
        echo "  $NIXOS_CONFIG_PATH"
        echo
        echo "This repository contains the NixOS configuration for shimboot."
        echo "Please ensure assemble-final.sh has cloned the repository correctly."
        echo
        echo "If the repository exists elsewhere, you can create a symlink:"
        echo "  sudo ln -sf /path/to/nixos-shimboot/flake.nix /etc/nixos/flake.nix"
        exit 1
    end

    echo
    echo "[setup_nixos_config] Done."
end
