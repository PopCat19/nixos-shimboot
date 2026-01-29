#!/usr/bin/env fish

# Proxify Command
# Purpose: Run a command with proxy settings via uwsm or directly
# Usage: proxify <command> [args...]
#        echo <command> | proxify

function proxify
    set -l cmd

    # If no arguments, read from stdin
    if test -z "$argv"
        if test -t 0
            echo "Usage: proxify <command> [args...]"
            echo "       echo <command> | proxify"
            return 1
        end
        set cmd (cat | string trim)
        if test -z "$cmd"
            echo "Error: no command provided via stdin"
            return 1
        end
    else
        set cmd $argv
    end

    if not set -q all_proxy
        set_color yellow; echo "[WARN] No proxy env. Run: proxy_on"; set_color normal
        $cmd
        return 1
    end

    set -l proxy_addr (string replace -r '^[^:]+://' '' "$all_proxy")
    set_color cyan; echo "[RUN] $cmd[1] → $proxy_addr"; set_color normal

    # If uwsm is available, use it to launch so the app inherits the session env
    if command -q uwsm
        uwsm app -- $cmd --proxy-server="socks5://$proxy_addr"
    else
        $cmd --proxy-server="socks5://$proxy_addr" &
        disown
    end
end
