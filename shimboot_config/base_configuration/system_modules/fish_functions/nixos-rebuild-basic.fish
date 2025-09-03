function nixos-rebuild-basic
    # Validate NIXOS_CONFIG_DIR
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

    # Determine kernel version and whether to disable sandbox (namespaces require >= 5.6)
    set -l kver (uname -r)
    set -l disable_sandbox 0

    # Simplified kernel version check
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