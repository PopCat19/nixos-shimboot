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
    path = [ pkgs.iproute2 pkgs.nettools ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = "yes";
      ExecStart = pkgs.writeShellScript "network-status" ''
        echo "=== Network Status ==="
        
        # Poll for WiFi connection (5 retries with increasing backoff)
        for delay in 3 5 10 15 30; do
          has_ip=$(ip -br addr show | grep -v UNKNOWN | grep -v LOOPBACK | grep -E 'UP|DORMANT' | head -1 || true)
          if [ -n "$has_ip" ]; then
            break
          fi
          sleep "$delay"
        done
        
        echo "Connected interfaces:"
        ip -br addr show | grep -v LOOPBACK || true
        
        echo ""
        echo "SSH access:"
        for addr in $(hostname -I 2>/dev/null); do
          echo "  ssh $USER@$addr"
        done
      '';
      StandardOutput = "journal+console";
    };
  };
}
