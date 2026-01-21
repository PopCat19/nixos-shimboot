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
    set -l git_cache_file "/tmp/.fastfetch_git_$user"
    if type -q fastfetch
        # Refresh cache if missing or older than 5 minutes
        if not test -f $cache_file; or test (math (date +%s) - (stat -c %Y $cache_file)) -gt 300
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
        set -l git_info ""
        if test -d "$config_dir"
            set_color brcyan; echo "Config: $config_dir"

            if test -d "$config_dir/.git"
                set -l current_head (git -C $config_dir rev-parse HEAD 2>/dev/null)
                set -l cached_head ""
                set -l cached_info ""

                if test -f $git_cache_file
                    set cached_head (head -n1 $git_cache_file 2>/dev/null)
                    set cached_info (tail -n+2 $git_cache_file 2>/dev/null)
                end

                if test "$current_head" = "$cached_head"; and test -n "$cached_info"
                    set git_info "$cached_info"
                else
                    set -l branch (git -C $config_dir rev-parse --abbrev-ref HEAD 2>/dev/null)
                    set -l commit (git -C $config_dir rev-parse --short HEAD 2>/dev/null)
                    if test -n "$branch"
                        set git_info "$branch @ $commit"
                    end
                    echo "$current_head" > $git_cache_file 2>/dev/null
                    echo "$git_info" >> $git_cache_file 2>/dev/null
                end

                if test -n "$git_info"
                    set_color normal; echo "Git: $git_info"
                end
            end

        # Dynamically discover and display helper functions
        set -l helper_functions
        set -l helper_patterns "show-shortcuts" "expand_rootfs" "fix-steam-bwrap" "setup_nixos" "setup_nixos_config" "nixos-" "setup_" "shimboot_" "fix" "list" "harvest"

        for pattern in $helper_patterns
            set -l matches (functions | grep "$pattern" | head -3)
            if test -n "$matches"
                for match in $matches
                    if not contains "$match" $helper_functions
                        set helper_functions $helper_functions "$match"
                    end
                end
            end
        end

        # If we found helper functions, display them
        if test -n "$helper_functions"
            set -l helper_list (string join " • " $helper_functions)
            set_color brwhite; echo "Helpers: $helper_list"
        else
            # Fallback to common helpers if none found
            set_color brwhite; echo "Helpers: expand_rootfs • fix-steam-bwrap • setup_nixos • setup_nixos_config"
        end
    else
        set_color bryellow; echo "[WARN] No nixos-config detected."
        set_color normal; echo "Run: setup_nixos to initialize"
    end

    # 5. Footer
    set_color grey; echo (date "+%a, %b %d %Y  %H:%M:%S"); set_color normal
end
