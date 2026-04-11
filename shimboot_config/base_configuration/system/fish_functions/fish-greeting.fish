#!/usr/bin/env fish

# Fish Greeting Function
#
# Purpose: Display customized shell greeting with system information.
#
# This function:
# - Shows user@hostname with colors
# - Displays fastfetch system info with caching
# - Shows system uptime
# - Displays NixOS config directory and git status
# - Lists available helper functions

function fish_greeting
    # 1. Use built-in variables (Instant, no external process)
    set -l config_dir "$NIXOS_CONFIG_DIR"
    set -l host $hostname
    set -l user $USER
    set -l cache_file "/tmp/.fastfetch_cache_$user"
    set -l git_cache_file "/tmp/.git_cache_$user"

    set_color brgreen; echo -n "$user"
    set_color normal; echo -n "@"
    set_color brcyan; echo "$host"

    if type -q fastfetch
        # If cache exists, print it immediately (instant)
        if test -f $cache_file
            cat $cache_file
        else
            # Fallback for very first run only
            set_color green; echo "System: Initializing cache..."
            set_color normal
        end

        # Update cache in the BACKGROUND (&) so it never blocks startup.
        # This checks age and updates if needed without making you wait.
        begin
            set -l needs_update 0
            if not test -f $cache_file
                set needs_update 1
            else
                # Check if older than 30 mins (1800s)
                set -l last_mod (stat -c %Y $cache_file 2>/dev/null; or echo 0)
                set -l now (date +%s)
                if test (math "$now - $last_mod") -gt 1800
                    set needs_update 1
                end
            end

            if test $needs_update -eq 1
                fastfetch --load-config none \
                    --disable title os kernel uptime packages \
                    --disable wm dde resolution theme icons term \
                    --disable font host cpu gpu memory disk \
                    > $cache_file 2>/dev/null
            end
        end & # <--- The ampersand detaches this process

        # Disown the background job to prevent "Job ... terminated" messages
        disown 2>/dev/null

    else
        # Fast fallback
        set_color green; echo "System:" (uname -sr)
        set_color normal
    end

    if test -f /proc/uptime
        read -d . uptime_sec uptime_frac < /proc/uptime
        set -l uptime_min (math "$uptime_sec / 60")
        if test $uptime_min -gt 0
            set_color yellow; echo "Uptime:" (math --scale=1 "$uptime_min / 60") "hours"
        end
    end

    if test -d "$config_dir"
        set_color brcyan; echo "Config: $config_dir"

        set -l git_info ""
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

        # 6. Helpers
        set -l known_helpers \
            expand-rootfs \
            setup-nixos \
            setup-nixos-config \
            fix-steam-bwrap \
            bwrap-lsm-workaround \
            setup-bwrap-workaround \
            nixos-rebuild-basic \
            nixos-flake-update \
            migration-status

        set -l found_helpers
        for helper in $known_helpers
            if type -q $helper
                set found_helpers $found_helpers $helper
            end
        end

        if test -n "$found_helpers"
            set_color brwhite; echo "Helpers: "(string join " • " $found_helpers)
        else
            set_color brwhite; echo "Helpers: none found"
        end
    else
        set_color bryellow; echo "[WARN] No nixos-config detected."
        set_color normal; echo "Run: setup_nixos to initialize"
    end

    set_color grey; echo (date "+%a, %b %d %Y  %H:%M:%S"); set_color normal
end
