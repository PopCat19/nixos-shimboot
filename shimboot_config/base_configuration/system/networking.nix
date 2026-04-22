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
  # Shows IP address and connection status on console
  systemd.services.network-status = lib.mkIf headless {
    description = "Network Status Display";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.iproute2 pkgs.nettools pkgs.iw ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = "yes";
      ExecStart = pkgs.writeShellScript "network-status" ''
        echo "=== Network Status ==="
        echo ""
        
        # Show all interfaces (connected or not)
        echo "Interfaces:"
        ip -br addr show | grep -v LOOPBACK 2>/dev/null || echo "  Waiting for interfaces..."
        
        # Show WiFi connection state if available
        if command -v iw >/dev/null 2>&1; then
          for iface in $(iw dev | grep Interface | awk '{print $2}' 2>/dev/null); do
            state=$(iw dev "$iface" link 2>/dev/null | head -1)
            if echo "$state" | grep -q "Connected"; then
              ssid=$(iw dev "$iface" link 2>/dev/null | grep SSID | sed 's/.*SSID: //')
              echo "WiFi: $iface - connected to $ssid"
            else
              echo "WiFi: $iface - $state"
            fi
          done
        fi
        
        echo ""
        echo "SSH access:"
        ips=$(hostname -I 2>/dev/null || true)
        if [ -n "$ips" ]; then
          for addr in $ips; do
            echo "  ssh user@$addr"
          done
        else
          echo "  Waiting for IP address..."
        fi
      '';
      StandardOutput = "journal+console";
    };
  };
}
