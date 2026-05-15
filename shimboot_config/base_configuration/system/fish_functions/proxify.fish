# proxify.fish
#
# Purpose: Run commands detached from PTY with proxy settings
#
# This module:
# - Accepts command via arguments or stdin
# - Prompts to enable proxy if not already active
# - Injects --proxy-server for Chromium/Electron apps
# - Wraps non-Chromium apps with proxychains for socket-level proxying
# - Detaches process via uwsm or standard backgrounding
# - Decouples application lifecycle from shell
#
# Rationale: Chromium apps accept --proxy-server natively; other apps need
# proxychains LD_PRELOAD interception to route arbitrary sockets.

function proxify
    set -l cmd_args

    if test -z "$argv"
        if test -t 0
            echo "Usage: proxify <command> [args...]"
            return 1
        end
        set cmd_args (cat | string split " ")
    else
        set cmd_args $argv
    end

    if not set -q all_proxy
        set_color yellow; echo "[INFO] Enabling proxy..."; set_color normal
        proxy_on
        if not set -q all_proxy
            set_color red; echo "[ERROR] proxy_on failed to set all_proxy"; set_color normal
            return 1
        end
    end

    if set -q all_proxy
        set -l proxy_addr (string replace -r '^[^:]+://' '' "$all_proxy")
        set_color cyan; echo "[RUN] $cmd_args[1] -> $proxy_addr"; set_color normal

        set -l cmd_name (basename "$cmd_args[1]")
        set -l chromium_apps chrome chromium google-chrome brave edge opera vivaldi electron

        if contains $cmd_name $chromium_apps
            set cmd_args $cmd_args --proxy-server="socks5://$proxy_addr"
        end
    end

    if command -q uwsm
        uwsm app -- $cmd_args >/dev/null 2>&1 &
        disown
    else
        $cmd_args >/dev/null 2>&1 &
        disown
    end
end
