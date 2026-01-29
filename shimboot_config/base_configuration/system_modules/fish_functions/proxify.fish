#!/usr/bin/env fish

# Proxify Command
# Purpose: Run a command with proxy settings via uwsm or directly
# Usage: proxify <app_name>

function proxify
    if not set -q all_proxy
        set_color yellow; echo "[WARN] No proxy env. Run: proxy_on"; set_color normal
        $argv
        return 1
    end

    set -l proxy_addr (string replace -r '^[^:]+://' '' "$all_proxy")
    set_color cyan; echo "[RUN] $argv[1] → $proxy_addr"; set_color normal

    # If uwsm is available, use it to launch so the app inherits the session env
    if command -q uwsm
        uwsm app -- $argv --proxy-server="socks5://$proxy_addr"
    else
        $argv --proxy-server="socks5://$proxy_addr" &
        disown
    end
end
