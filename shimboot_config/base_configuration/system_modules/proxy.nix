# Proxy Configuration Module
#
# Purpose: Auto-configure system proxy based on Android WiFi Direct SSID
# Dependencies: networkmanager
# Related: networking.nix, environment.nix
#
# This module:
# - Configures DNS nameservers
# - Sets proxy environment variables for user shell sessions on WiFi Direct
# - Uses NetworkManager dispatcher to inject proxy into systemd environment
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.proxy;

  # Convert shell glob pattern to grep regex prefix
  # "DIRECT-*" -> "DIRECT-"
  patternBase = builtins.substring 0 (
    builtins.stringLength cfg.androidWifiDirect.pattern - 1
  ) cfg.androidWifiDirect.pattern;
in
{
  options.proxy = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable auto-configuration of proxy for Android WiFi Direct";
    };

    androidWifiDirect = {
      pattern = lib.mkOption {
        type = lib.types.str;
        default = "DIRECT-*";
        description = "SSID pattern to match for Android WiFi Direct";
      };
    };

    urls = {
      http = lib.mkOption {
        type = lib.types.str;
        default = "http://192.168.49.1:8282";
        description = "HTTP proxy URL";
      };
      https = lib.mkOption {
        type = lib.types.str;
        default = "http://192.168.49.1:8282";
        description = "HTTPS proxy URL";
      };
      socks = lib.mkOption {
        type = lib.types.str;
        default = "socks5h://192.168.49.1:1080";
        description = "SOCKS5 proxy URL";
      };
      noProxy = lib.mkOption {
        type = lib.types.str;
        default = "localhost,127.0.0.1";
        description = "Comma-separated list of hosts to bypass proxy";
      };
    };

    nameservers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "8.8.8.8"
        "1.1.1.1"
      ];
      description = "DNS nameservers to use";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.nameservers = cfg.nameservers;

    environment.shellInit = ''
      # Check for Android WiFi Direct SSID
      SSID=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2)
      if [[ "$SSID" == ${cfg.androidWifiDirect.pattern} ]]; then
        export http_proxy="${cfg.urls.http}"
        export https_proxy="${cfg.urls.https}"
        export all_proxy="${cfg.urls.socks}"
        export no_proxy="${cfg.urls.noProxy}"
        # Sync uppercase versions
        export HTTP_PROXY="$http_proxy"
        export HTTPS_PROXY="$https_proxy"
        export ALL_PROXY="$all_proxy"
        export NO_PROXY="$no_proxy"
      fi
    '';

    networking.networkmanager.dispatcherScripts = [
      {
        source = pkgs.writeText "wifi-direct-proxy-toggle" ''
          #!/bin/sh
          SSID=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2)

            if echo "$SSID" | grep -q '^${patternBase}'; then
              # 1. System-level (for nix-daemon)
              systemctl set-environment \
                HTTP_PROXY="${cfg.urls.http}" \
                HTTPS_PROXY="${cfg.urls.https}" \
                ALL_PROXY="${cfg.urls.socks}" \
                NO_PROXY="${cfg.urls.noProxy}"

              # 2. User-level (for Electron apps & Desktop Environment)
              for user_id in $(loginctl list-users --no-legend | awk '{print $1}'); do
                sudo -u "#$user_id" DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$user_id/bus \
                  systemctl --user set-environment \
                    HTTP_PROXY="${cfg.urls.http}" \
                    HTTPS_PROXY="${cfg.urls.https}" \
                    ALL_PROXY="${cfg.urls.socks}" \
                    NO_PROXY="${cfg.urls.noProxy}"
              done

              systemctl restart nix-daemon
              logger "Nix Proxy: Enabled for $SSID and User Sessions"
            else
              # 1. System-level
              systemctl unset-environment HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY

              # 2. User-level
              for user_id in $(loginctl list-users --no-legend | awk '{print $1}'); do
                sudo -u "#$user_id" DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$user_id/bus \
                  systemctl --user unset-environment HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY
              done

              systemctl restart nix-daemon
              logger "Nix Proxy: Disabled"
            fi
        '';
        type = "basic";
      }
    ];
  };
}
