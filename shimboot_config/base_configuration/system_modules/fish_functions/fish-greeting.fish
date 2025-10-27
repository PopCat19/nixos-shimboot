# fish_functions/fish-greeting.fish
# Purpose: Minimal, context-aware Fish shell greeting for base Shimboot
# Displays system identity, optional config hints, and available helpers

function fish_greeting
    set -l config_dir $NIXOS_CONFIG_DIR
    set -l host (hostname)
    set -l user (whoami)

    # Prefer fastfetch or neofetch for system summary
    if type -q fastfetch
        fastfetch
        echo ""
    else if type -q neofetch
        neofetch --disable uptime packages shell de wm resolution theme icons term kernel --off
        echo ""
    else
        echo "-------------------------------------------"
        echo "Welcome to NixOS Shimboot"
        echo "Host: $host | User: $user | Kernel: (uname -sr)"
        echo "-------------------------------------------"
        echo ""
    end

    # Configuration path summary
    if test -d "$config_dir"
        echo "Active config: $config_dir"
        echo ""
        echo "Common commands:"
        echo "  • nrb      – rebuild system using current flake"
        echo "  • flup     – update flake inputs"
        echo ""
    else
        echo "No nixos-config detected."
        echo "You can initialize it with:"
        echo "  setup_nixos"
        echo ""
    end

    echo "Tip: run 'sudo expand_rootfs' if this is a new install."
    echo ""
end