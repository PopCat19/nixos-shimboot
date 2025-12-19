#!/usr/bin/env fish

# NixOS Rebuild Basic Function
#
# Purpose: Simplify NixOS rebuild with kernel compatibility.
# Dependencies: nixos-rebuild, sudo, uname
# Related: nixos-flake-update.fish, fish.nix
#
# This function:
# - Validates NIXOS_CONFIG_DIR
# - Checks kernel version for sandbox settings
# - Runs nixos-rebuild switch with appropriate flags
# - Handles directory navigation automatically

function nixos-rebuild-basic
    if not set -q NIXOS_CONFIG_DIR; or not test -d "$NIXOS_CONFIG_DIR"
        echo "❌ Error: NIXOS_CONFIG_DIR is not set or invalid."
        return 1
    end

    set -l original_dir (pwd)
    cd "$NIXOS_CONFIG_DIR"

    # Kernel Sandbox Check (Fix for older kernels < 5.6)
    set -l kver (uname -r)
    set -l nix_args "switch" "--flake" "."
    
    if string match -qr '^([0-4]\.|5\.[0-5][^0-9])' "$kver"
        echo "⚠️  Kernel $kver (< 5.6) detected. Disabling sandbox."
        set -a nix_args "--option" "sandbox" "false"
    else
        echo "🔐 Kernel $kver detected. Using default sandbox."
    end

    # Pass additional arguments from caller
    set -a nix_args $argv

    echo "🚀 Running NixOS rebuild..."
    echo "Command: sudo nixos-rebuild $nix_args"

    if sudo nixos-rebuild $nix_args
        echo "✅ Build succeeded"
        cd "$original_dir"
        return 0
    else
        echo "❌ Build failed"
        cd "$original_dir"
        return 1
    end
end