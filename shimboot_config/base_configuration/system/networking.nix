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
in
{
  networking = {
    dhcpcd.enable = lib.mkForce false;
    firewall = {
      enable = lib.mkForce false;
    };
    hostName = hostname;
    # Use wpa_supplicant directly for headless, NetworkManager for desktop
    wireless = lib.mkIf headless {
      enable = lib.mkDefault true;
      userControlled = lib.mkDefault false;
      networks = { } // lib.mkDefault { };
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
      ExecStart = pkgs.writeShellScriptBin "network-status-poll" ''
        echo "=== Network Status ==="
        for i in $(seq 1 12); do
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

          # Find WiFi interfaces from sysfs (no pipelines)
          wifi_iface=""
          for dev in /sys/class/net/*; do
            [ -d "$dev" ] || continue
            name=$(basename "$dev")
            case "$name" in
              wlan*|wlp*)
                wifi_iface="$name"
                break
                ;;
            esac
          done

          if [ -n "$wifi_iface" ]; then
            ${pkgs.iproute2}/bin/ip -br link show "$wifi_iface" 2>/dev/null > /tmp/netstatus-wifi
            read -r if_name if_state rest < /tmp/netstatus-wifi
            rm -f /tmp/netstatus-wifi
            echo "  WiFi ($wifi_iface): $if_state"
          fi

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
