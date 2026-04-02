# Networking Configuration Module
#
# Purpose: Configure network services for ChromeOS compatibility
# Dependencies: networkmanager, wpa_supplicant
# Related: hardware.nix, services.nix
#
# This module:
# - Enables NetworkManager with wpa_supplicant backend
# - Configures firewall with SSH access
# - Loads WiFi kernel modules for ChromeOS devices
# - Handles rfkill unblocking for WLAN
{
  pkgs,
  lib,
  userConfig,
  ...
}:
{
  networking = {
    dhcpcd.enable = lib.mkForce false;
    firewall = {
      enable = false;
    };
    hostName = userConfig.host.hostname;
    networkmanager = {
      enable = true;
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
}
