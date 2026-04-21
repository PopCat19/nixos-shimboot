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
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = "yes";
      ExecStart = "${pkgs.bash}/bin/bash -c 'echo \"=== Network Status ===\"; echo \"Connected interfaces:\"; ip -br addr show | grep -v LOOPBACK || true; echo \"\"; echo \"SSH access:\"; for addr in $(hostname -I 2>/dev/null); do echo \"  ssh $USER@$addr\"; done'";
      StandardOutput = "journal+console";
    };
  };
}
