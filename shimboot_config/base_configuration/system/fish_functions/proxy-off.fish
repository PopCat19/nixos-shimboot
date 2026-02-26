#!/usr/bin/env fish

# Proxy Environment Off
# Purpose: Disable proxy environment variables
# Usage: proxy_off

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
