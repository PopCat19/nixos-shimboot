#!/usr/bin/env fish

# Fish Greeting Function
#
# Purpose: Display customized shell greeting with system information.
# Dependencies: fastfetch, git, hostname, whoami, stat
# Related: fish.nix, list-fish-helpers.fish
#
# This function:
# - Shows user@hostname with colors
# - Displays fastfetch system info with caching
# - Shows system uptime
# - Displays NixOS config directory and git status
# - Lists available helper functions

function fish_greeting
    set -l config_dir "$NIXOS_CONFIG_DIR"
    set -l host (hostname)
    set -l user (whoami)
    set -l cache_file "/tmp/.fastfetch_cache_$user"
    
    # 1. Header
    set_color brgreen; echo -n "$user"
    set_color normal; echo -n "@"
    set_color brcyan; echo "$host"

    # 2. Fastfetch with Caching
    if type -q fastfetch
        # Refresh cache if missing or older than 2 minutes
        if not test -f $cache_file; or test (math (date +%s) - (stat -c %Y $cache_file)) -gt 120
            fastfetch --load-config none \
                --disable title os kernel uptime packages \
                --disable wm dde resolution theme icons term \
                --disable font host cpu gpu memory disk \
                > $cache_file 2>/dev/null
        end
        cat $cache_file
    # Fallback if fastfetch fails or is missing
    else if not test -s $cache_file
        set_color green; echo "System:" (uname -sr)
        set_color brmagenta; echo "CPU:" (string trim (string split -f2 ":" (grep -m1 "model name" /proc/cpuinfo)))
        set_color normal
    end

    # 3. Uptime
    set -l uptime_min (math (string split . (cat /proc/uptime))[1] / 60)
    if test $uptime_min -gt 0
        set_color yellow; echo "Uptime:" (math --scale=1 "$uptime_min / 60") "hours"
    end

    # 4. Config & Git Status
    if test -d "$config_dir"
        set_color brcyan; echo "Config: $config_dir"
        
        if test -d "$config_dir/.git"
            set -l branch (git -C $config_dir rev-parse --abbrev-ref HEAD 2>/dev/null)
            set -l commit (git -C $config_dir rev-parse --short HEAD 2>/dev/null)
            if test -n "$branch"
                set_color normal; echo "Git: $branch @ $commit"
            end
        end
        
        set_color brwhite; echo "Helpers: nrb • flup • cdn • setup_nixos • list-fish-helpers"
    else
        set_color bryellow; echo "⚠️  No nixos-config detected."
        set_color normal; echo "Run: setup_nixos to initialize"
    end

    # 5. Footer
    set_color brblack; echo (date "+%a, %b %d %Y  %H:%M:%S"); set_color normal
end