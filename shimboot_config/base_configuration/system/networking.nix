# Networking Configuration Module
#
# Purpose: Configure network services for ChromeOS compatibility
# Dependencies: networkmanager, wpa_supplicant
# Related: hardware.nix, services.nix
#
# This module:
# - Enables NetworkManager with wpa_supplicant backend (base)
# - Enables wpa_supplicant for headless builds
# - Configures firewall with SSH access
# - Loads WiFi kernel modules for ChromeOS devices
# - Handles rfkill unblocking for WLAN
{
  pkgs,
  lib,
  userConfig,
  headless ? false,
  ...
}:
let
  hostname = userConfig.host.hostname or userConfig.hostname;

  # Load WiFi secrets from gitignored file (not tracked in version control)
  # Build with `path:` fetcher to include untracked files:
  #   nix build "path:$PWD#raw-rootfs-headless"
  # Note: path is relative to this file (shimboot_config/base_configuration/system/)
  secretsPath = ../../secrets.nix;
  secrets = if builtins.pathExists secretsPath then import secretsPath else { wifi = null; };
  wifi = secrets.wifi or null;
  wifiConfigured = wifi != null && wifi.ssid != "";
in
{
  networking = {
    dhcpcd.enable = if headless then lib.mkForce true else lib.mkForce false;
    firewall = {
      enable = lib.mkForce false;
    };
    hostName = hostname;
    # Use wpa_supplicant directly for headless, NetworkManager for desktop
    wireless = lib.mkIf headless {
      enable = lib.mkDefault true;
      userControlled = lib.mkDefault false;
      networks = if wifiConfigured then
        { "${wifi.ssid}" = { psk = wifi.psk; }; }
      else
        { };
    };
    networkmanager = {
      enable = lib.mkDefault (!headless);
    };
    timeServers = [ "pool.ntp.org" ];
  };

  boot.kernelModules = [
    "iwlmvm"
    "ccm"
  ];

  system.activationScripts.rfkillUnblockWlan = {
    text = ''
      ${pkgs.util-linux}/bin/rfkill unblock wlan
    '';
    deps = [ ];
  };

  # Headless backlight control
  # 40% on boot, 20% after 2 minutes (no keyboard idle detection via frecon-lite)
  systemd.services.headless-backlight = lib.mkIf headless {
    description = "Headless Backlight Control";
    after = [ "multi-user.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "headless-backlight" ''
        # Find backlight (portable across GPU vendors)
        bl_dir=""
        for d in /sys/class/backlight/*; do
          [ -d "$d" ] || continue
          bl_dir="$d"
          break
        done

        if [ -z "$bl_dir" ]; then
          echo "No backlight device found"
          exit 0
        fi

        max=$(cat "$bl_dir/max_brightness")
        init=$((max * 40 / 100))
        dim=$((max * 20 / 100))

        echo "$init" > "$bl_dir/brightness" 2>/dev/null || true
        echo "Brightness: $init/$max (40%))"

        # Dim to 20% after 2 minutes
        sleep 120
        echo "$dim" > "$bl_dir/brightness" 2>/dev/null || true
        echo "Brightness: $dim/$max (20%))"
      '';
    };
  };

  # Network status display service for headless builds
  # Polls every 5 seconds for 60 seconds, showing connection status updates
  systemd.services.network-status = lib.mkIf headless {
    description = "Network Status Display";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.iproute2 pkgs.nettools ];
    serviceConfig = {
      Type = "simple";
      ExecStart = pkgs.writeShellScript "network-status-poll" ''
        echo "=== Network Status ==="
        for _ in $(seq 1 12); do
          echo ""
          echo "[$(date '+%H:%M:%S')] Interface status:"

          # Get interfaces, store temporarily (broken pipe safe)
          ${pkgs.iproute2}/bin/ip -br addr show > /tmp/netstatus-ip 2>/dev/null || true
          while IFS= read -r line || [ -n "$line" ]; do
            case "$line" in
              *LOOPBACK*) continue ;;
              *) echo "  $line" ;;
            esac
          done < /tmp/netstatus-ip
          rm -f /tmp/netstatus-ip

          # Get IPs without pipelines
          ${pkgs.nettools}/bin/hostname -I 2>/dev/null > /tmp/netstatus-hostname
          ips=$(cat /tmp/netstatus-hostname)
          rm -f /tmp/netstatus-hostname

          if [ -n "$ips" ]; then
            # Check for non-loopback IPs using shell only
            has_real_ip=0
            for addr in $ips; do
              case "$addr" in
                127.*|::1) continue ;;
                *)
                  has_real_ip=1
                  echo ""
                  echo "SSH access:"
                  echo "  ssh user@$addr"
                  break
                  ;;
              esac
            done

            if [ "$has_real_ip" -eq 1 ]; then
              echo ""
              echo "Network connected. Stopping status display."
              break
            fi
          fi

          sleep 5
        done
      '';
      StandardOutput = "journal+console";
      Restart = "no";
    };
  };
}
