# NixOS Rebuild Basic Function
#
# Purpose: Perform basic NixOS system rebuild with kernel compatibility checks
# Dependencies: nix, sudo
# Related: fish-functions.nix, fish.nix
#
# This function:
# - Validates NIXOS_CONFIG_DIR environment variable
# - Checks kernel version for sandbox compatibility
# - Performs nixos-rebuild switch with appropriate options

function nixos-rebuild-basic
    if not set -q NIXOS_CONFIG_DIR
        echo "❌ Error: NIXOS_CONFIG_DIR environment variable is not set."
        echo "   Please set it to your NixOS configuration directory (e.g., export NIXOS_CONFIG_DIR=/etc/nixos)"
        return 1
    end

    if not test -d $NIXOS_CONFIG_DIR
        echo "❌ Error: NIXOS_CONFIG_DIR ($NIXOS_CONFIG_DIR) is not a valid directory."
        return 1
    end

    set -l original_dir (pwd)
    cd $NIXOS_CONFIG_DIR

    set -l kver (uname -r)
    set -l disable_sandbox 0

    if string match -qr '^([0-9]+)\.([0-9]+)' $kver
        set -l major (string split . $kver)[1]
        set -l minor (string split . $kver)[2]
        if test $major -lt 5 -o \( $major -eq 5 -a $minor -lt 6 \)
            set disable_sandbox 1
        end
    else
        echo "⚠️  Warning: Could not parse kernel version $kver. Assuming sandbox is supported."
    end

    set -l nix_args switch --flake .

    if test $disable_sandbox -eq 1
        echo "⚠️  Kernel $kver detected (< 5.6). Disabling nix sandbox for rebuild."
        set nix_args $nix_args --option sandbox false
    else
        echo "🔐 Kernel $kver detected (>= 5.6). Using default sandboxed build."
    end

    echo "Command: sudo nixos-rebuild $nix_args"
    echo "🚀 Running NixOS rebuild..."
    if sudo nixos-rebuild $nix_args
        echo "✅ Build succeeded"
    else
        echo "❌ Build failed"
        cd $original_dir
        return 1
    end
    cd $original_dir
end