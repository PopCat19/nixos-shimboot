#!/usr/bin/env fish

# Proxy Environment Off
# Purpose: Disable proxy environment variables
# Usage: proxy_off

function proxy-off
    set -e http_proxy
    set -e https_proxy
    set -e all_proxy
    set -e no_proxy

    if command -q systemctl
        systemctl --user unset-environment http_proxy https_proxy all_proxy no_proxy

        # System-level for nix-daemon
        sudo systemctl unset-environment \
            http_proxy https_proxy all_proxy no_proxy \
            HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY
        sudo systemctl restart nix-daemon
    end

    set_color red; echo -n "[OK]"; set_color normal; echo " Proxy disabled"
end
