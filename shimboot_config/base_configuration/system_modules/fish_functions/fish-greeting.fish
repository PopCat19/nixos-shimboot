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
    # 1. Use built-in variables (Instant, no external process)
    set -l config_dir "$NIXOS_CONFIG_DIR"
    set -l host $hostname
    set -l user $USER
    set -l cache_file "/tmp/.fastfetch_cache_$user"

    # 2. Header
    set_color brgreen; echo -n "$user"
    set_color normal; echo -n "@"
    set_color brcyan; echo "$host"

    # 3. Async Fastfetch (The major speedup)
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
                # Run fastfetch and save to cache
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

    # 4. Optimized Uptime (No 'cat' or pipes)
    # Read /proc/uptime directly into variable using built-in 'read'
    if test -f /proc/uptime
        read -d . uptime_sec uptime_frac < /proc/uptime
        set -l uptime_min (math "$uptime_sec / 60")
        if test $uptime_min -gt 0
            set_color yellow; echo "Uptime:" (math --scale=1 "$uptime_min / 60") "hours"
        end
    end

    # 5. Config Check
    if test -d "$config_dir"
        set_color brcyan; echo "Config: $config_dir"
        
        # 6. Helpers
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

    # 7. Footer
    set_color grey; echo (date "+%a, %b %d %Y  %H:%M:%S"); set_color normal
end
