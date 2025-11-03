# fish_functions/fish-greeting.fish
# Purpose: Minimal, context-aware Fish shell greeting for base Shimboot
# Displays system identity, optional config hints, and available helpers

function fish_greeting
    set -l config_dir $NIXOS_CONFIG_DIR
    set -l host (hostname)
    set -l user (whoami)
    set -l cache_file /tmp/.fastfetch_cache_$user
    set -l uptime (math (cat /proc/uptime | cut -d. -f1) / 60)

    # Header line
    set_color brgreen
    echo -n "$user"; set_color normal; echo -n "@"; set_color brcyan; echo "$host"

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
    end

    # Fallback quick system info (for minimal envs without fastfetch output)
    if not test -s $cache_file
        set_color green
        echo "System:" (uname -sr)
        set_color brmagenta
        echo "CPU:" (string trim (cat /proc/cpuinfo | grep 'model name' -m1 | cut -d: -f2))
        set_color normal
    end

    # Optional uptime summary
    if test $uptime -gt 0
        set_color yellow
        echo "Uptime:" (math --scale=1 "$uptime / 60") "hours"
        set_color normal
    end

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
        set_color brwhite
        echo "Helpers: nrb • flup • cdn • setup_nixos • list-fish-helpers"
        set_color normal
    else
        set_color bryellow
        echo "⚠️  No nixos-config detected."
        set_color normal
        echo "Run: setup_nixos to initialize"
    end
    set_color brblack
    echo (date "+%a, %b %d %Y  %H:%M:%S")
    set_color normal
end