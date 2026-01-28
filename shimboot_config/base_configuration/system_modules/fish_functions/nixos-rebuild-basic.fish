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
    set_color red; echo "[ERROR] Error: NIXOS_CONFIG_DIR is not set or invalid."; set_color normal
    return 1
    end

    set -l original_dir (pwd)
    cd "$NIXOS_CONFIG_DIR"

    # Kernel Sandbox Check (Fix for older kernels < 5.6)
    set -l kver (uname -r)
    set -l nix_args "switch" "--flake" "."
    
    if string match -qr '^([0-4]\.|5\.[0-5][^0-9])' "$kver"
    set_color yellow; echo "[WARN] Kernel $kver (< 5.6) detected. Disabling sandbox."; set_color normal
    set -a nix_args "--option" "sandbox" "false"
    else
    set_color green; echo "[INFO] Kernel $kver detected. Using default sandbox."; set_color normal
    end

    # Pass additional arguments from caller
    set -a nix_args $argv

    set_color blue; echo "[STEP] Running NixOS rebuild..."; set_color normal
    set_color cyan; echo "Command: sudo -E nixos-rebuild $nix_args"; set_color normal

    if sudo -E nixos-rebuild $nix_args
    set_color green; echo "[SUCCESS] Build succeeded"; set_color normal
    cd "$original_dir"
    return 0
    else
    set_color red; echo "[ERROR] Build failed"; set_color normal
    cd "$original_dir"
    return 1
    end
end
