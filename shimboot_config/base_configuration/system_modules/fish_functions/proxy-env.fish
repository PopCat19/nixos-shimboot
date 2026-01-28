#!/usr/bin/env fish

# Proxy Environment Manager
# Purpose: Toggle proxy variables with overwritable defaults
# Usage: proxy_on [HOST] [HTTP_PORT] [SOCKS_PORT]
#        proxy_off
#        proxify <app_name>

function proxy_on
    set -l _host (test -n "$argv[1]"; and echo "$argv[1]"; or echo (set -q PROXY_HOST; and echo $PROXY_HOST; or echo "192.168.49.1"))
    set -l _http_port (test -n "$argv[2]"; and echo "$argv[2]"; or echo (set -q PROXY_HTTP_PORT; and echo $PROXY_HTTP_PORT; or echo "8282"))
    set -l _socks_port (test -n "$argv[3]"; and echo "$argv[3]"; or echo (set -q PROXY_SOCKS_PORT; and echo $PROXY_SOCKS_PORT; or echo "1080"))

    set -gx http_proxy "http://$_host:$_http_port"
    set -gx https_proxy "http://$_host:$_http_port"
    set -gx all_proxy "socks5h://$_host:$_socks_port"
    set -gx no_proxy "localhost,127.0.0.1,::1"

    # UWSM/Systemd Integration: Use systemctl to set user session env vars
    # This makes the proxy available to apps launched via uwsm app, rofi, etc.
    if command -q systemctl
        systemctl --user set-environment http_proxy=$http_proxy
        systemctl --user set-environment https_proxy=$https_proxy
        systemctl --user set-environment all_proxy=$all_proxy
        systemctl --user set-environment no_proxy=$no_proxy
    end
    
    # Backup for non-systemd setups
    if command -q dbus-update-activation-environment
        dbus-update-activation-environment --systemd http_proxy https_proxy all_proxy no_proxy 2>/dev/null
    end

    set_color green; echo -n "[OK] "
    set_color normal; echo "Proxy active: $_host (HTTP:$_http_port, SOCKS:$_socks_port)"
end

function proxy_off
    set -e http_proxy
    set -e https_proxy
    set -e all_proxy
    set -e no_proxy
    
    if command -q systemctl
        systemctl --user unset-environment http_proxy https_proxy all_proxy no_proxy
    end
    
    set_color red; echo "[OK]"; set_color normal; echo " Proxy disabled"
end

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