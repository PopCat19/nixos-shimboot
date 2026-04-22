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
    path = [ pkgs.iproute2 pkgs.nettools pkgs.iw pkgs.gnugrep ];
    serviceConfig = {
      Type = "simple";
      ExecStart = pkgs.writeShellScript "network-status-poll" ''
        echo "=== Network Status ==="
        for i in $(seq 1 12); do
          # Show interfaces without piped grep (avoid broken pipe errors)
          echo ""
          echo "[$(date '+%H:%M:%S')] Interface status:"
          ${pkgs.iproute2}/bin/ip -br addr show 2>/dev/null | while read line; do
            case "$line" in
              *LOOPBACK*) ;;
              *) echo "  $line" ;;
            esac
          done

          # Check for WiFi connection
          wifi_iface=$(${pkgs.iproute2}/bin/ip -br link show 2>/dev/null | ${pkgs.gnugrep}/bin/grep -E "wlan|wlp" | ${pkgs.coreutils}/bin/awk '{print $1}' | ${pkgs.coreutils}/bin/head -n1)
          if [ -n "$wifi_iface" ]; then
            wifi_state=$(${pkgs.iproute2}/bin/ip -br link show "$wifi_iface" 2>/dev/null | ${pkgs.coreutils}/bin/awk '{print $2}')
            echo "  WiFi ($wifi_iface): $wifi_state"
          fi

          # Show SSH access info when IP is available
          ips=$(hostname -I 2>/dev/null || true)
          if [ -n "$ips" ]; then
            # Filter out loopback, just show actual network IPs
            real_ips=$(echo "$ips" | tr ' ' '\n' | grep -v "^127\\." | grep -v "^::1$" | head -2)
            if [ -n "$real_ips" ]; then
              echo ""
              echo "SSH access:"
              for addr in $real_ips; do
                echo "  ssh user@$addr"
              done
            fi
          fi

          # Stop polling if we have a real network IP
          if [ -n "$ips" ] && echo "$ips" | grep -qv "^127\\."; then
            echo ""
            echo "Network connected. Stopping status display."
            break
          fi

          # Sleep 5 seconds before next poll
          sleep 5
        done
      '';
      StandardOutput = "journal+console";
      Restart = "no";
    };
  };
}
