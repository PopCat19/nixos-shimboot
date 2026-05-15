# proxy.nix
#
# Purpose: Unified proxy management for fish shell
#
# This module generates fish functions for enabling, disabling, and 
# utilizing a proxy (typically a SOCKS5H hotspot).
#
# It manages:
# - Environment variables (lower and upper case)
# - Systemd user environment
# - Systemd system environment (via sudo) for nix-daemon
# - DBus activation environment
# - The `proxify` helper for detaching proxy-aware apps

{ config, lib, ... }:
let
  proxyVars = [ "http_proxy" "https_proxy" "all_proxy" "no_proxy" ];
  proxyVarsUpper = map (v: lib.toUpper v) proxyVars;

  proxyOnBody = ''
function proxy_on
    set -l _host (test -n "$argv[1]"; and echo "$argv[1]"; or echo (set -q PROXY_HOST; and echo $PROXY_HOST; or echo "192.168.49.1"))
    set -l _http_port (test -n "$argv[2]"; and echo "$argv[2]"; or echo (set -q PROXY_HTTP_PORT; and echo $PROXY_HTTP_PORT; or echo "8282"))
    set -l _socks_port (test -n "$argv[3]"; and echo "$argv[3]"; or echo (set -q PROXY_SOCKS_PORT; and echo $PROXY_SOCKS_PORT; or echo "1080"))

    set -gx http_proxy "http://$_host:$_http_port"
    set -gx https_proxy "http://$_host:$_http_port"
    set -gx all_proxy "socks5h://$_host:$_socks_port"
    set -gx no_proxy "localhost,127.0.0.1,::1"

    ${lib.concatStringsSep "\n" (map (v: "    set -gx ${lib.toUpper v} $$${v}") proxyVars)}

    if command -q systemctl
        ${lib.concatStringsSep "\n" (map (v: "        systemctl --user set-environment ${v}=$$${v}") proxyVars)}

        sudo systemctl set-environment \
            ${lib.concatStringsSep " \\" (map (v: "${v}=$$${v}") proxyVars)} \
            ${lib.concatStringsSep " \\" (map (v: "${lib.toUpper v}=$$${v}") proxyVars)}
        sudo systemctl restart nix-daemon
    end

    if command -q dbus-update-activation-environment
        dbus-update-activation-environment --systemd ${lib.concatStringsSep " " (proxyVars ++ proxyVarsUpper)} 2>/dev/null
    end

    set_color green; echo -n "[OK] "
    set_color normal; echo "Proxy active: $_host (HTTP:$_http_port, SOCKS:$_socks_port)"
end
'';

  proxyOffBody = ''
function proxy_off
    ${lib.concatStringsSep "\n" (map (v: "    set -e ${v}") proxyVars)}
    ${lib.concatStringsSep "\n" (map (v: "    set -e ${lib.toUpper v}") proxyVarsUpper)}

    if command -q systemctl
        systemctl --user unset-environment ${lib.concatStringsSep " " proxyVars}

        sudo systemctl unset-environment \
            ${lib.concatStringsSep " " proxyVars} \
            ${lib.concatStringsSep " " proxyVarsUpper}
        sudo systemctl restart nix-daemon
    end

    set_color red; echo "[OK]"; set_color normal; echo " Proxy disabled"
end
'';

  proxifyBody = ''
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
'';

in {
  environment.etc = {
    "fish/functions/proxy-on.fish".text = proxyOnBody;
    "fish/functions/proxy-off.fish".text = proxyOffBody;
    "fish/functions/proxify.fish".text = proxifyBody;
  };
}
