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
  config,
  pkgs,
  lib,
  userConfig,
  ...
}: {
  networking = {
    dhcpcd.enable = false;
    firewall = {
      enable = true;
      trustedInterfaces = ["lo"];
      allowedTCPPorts = [
        22
      ];
      allowedUDPPorts = [
      ];
      checkReversePath = false;
    };
    hostName = userConfig.host.hostname;
    networkmanager = {
      enable = true;
      wifi.backend = "wpa_supplicant";
      wifi.powersave = false;
    };
    wireless.enable = false;
  };

  boot.kernelModules = ["iwlmvm" "ccm" "8021q" "tun"];

  system.activationScripts.rfkillUnblockWlan = {
    text = ''
      ${pkgs.util-linux}/bin/rfkill unblock wlan
    '';
    deps = [];
  };
}
