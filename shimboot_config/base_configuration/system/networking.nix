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
  config,
  userConfig,
  ...
}:
let
  headless = config.shimboot.headless;
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
    hostName = lib.mkDefault hostname;
    # Use wpa_supplicant directly for headless, NetworkManager for desktop
    wireless = lib.mkIf headless {
      enable = lib.mkDefault true;
      userControlled = lib.mkDefault false;
      networks = if wifiConfigured then { "${wifi.ssid}" = { inherit (wifi) psk; }; } else { };
    };
    networkmanager = {
      enable = lib.mkDefault (!headless);
    };
    timeServers = lib.mkDefault [ "pool.ntp.org" ];
  };

  boot.kernelModules = lib.mkDefault [
    "iwlmvm"
    "ccm"
  ];

  system.activationScripts.rfkillUnblockWlan = lib.mkDefault {
    text = ''
      ${pkgs.util-linux}/bin/rfkill unblock wlan
    '';
    deps = [ ];
  };

}
