# fish_functions/fish-greeting.fish
# Purpose: Minimal, context-aware Fish shell greeting for base Shimboot
# Displays system identity, optional config hints, and available helpers

function fish_greeting
    set -l config_dir $NIXOS_CONFIG_DIR
    set -l host (hostname)
    set -l user (whoami)
    set -l cache_file /tmp/.fastfetch_cache_$user

    # Use cached fastfetch output to reduce startup lag
    if type -q fastfetch
        if test -f $cache_file; and test (math (date +%s) - (stat -c %Y $cache_file)) -lt 120
            cat $cache_file
        else
            fastfetch --load-config none \
                --disable title os kernel uptime packages \
                --disable wm dde resolution theme icons term \
                --disable font host cpu gpu memory disk \
                > $cache_file 2>/dev/null; or true
            cat $cache_file
        end
        echo ""
    end

    # System summary line
    set_color green
    echo "System: " (uname -sr) " CPU: " (string replace -r ' +$' '' (cat /proc/cpuinfo | grep 'model name' -m1 | cut -d: -f2))
    set_color normal

    # Config summary
    if test -d "$config_dir"
        set_color brcyan
        echo "Config: $config_dir"
        set_color normal
        if test -d "$config_dir/.git"
            set -l branch (string trim (git -C $config_dir rev-parse --abbrev-ref HEAD 2>/dev/null))
            set -l commit (string sub -l 7 (git -C $config_dir rev-parse HEAD 2>/dev/null))
            echo "Git: $branch @ $commit"
        end
        echo "Helpful:  nrb (rebuild)   flup (flake update)   cdn (cd config)   setup_nixos   list-fish-helpers"
    else
        set_color bryellow
        echo "⚠️  No nixos-config detected."
        set_color normal
        echo "Run: setup_nixos to initialize"
    end

    echo (date "+%a, %b %d %Y  %H:%M:%S")
    echo ""
end