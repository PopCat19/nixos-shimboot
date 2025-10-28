# Power Management Configuration Module
#
# Purpose: Configure power management for ChromeOS devices
# Dependencies: tlp, thermald, upower
# Related: hardware.nix, services.nix
#
# This module:
# - Enables system power management
# - Configures thermal management for Intel CPUs
# - Enables battery monitoring and power saving
# - Configures WiFi power saving
{
  config,
  pkgs,
  lib,
  ...
}: {
  powerManagement = {
    enable = true;
    cpuFreqGovernor = lib.mkDefault "performance";
  };

  services = {
    upower.enable = lib.mkDefault true;

    auto-cpufreq = {
      enable = lib.mkDefault true;
      settings = {
        battery = {
          governor = lib.mkDefault "performance";
          turbo = lib.mkDefault "auto";
        };
        charger = {
          governor = "performance";
          turbo = "auto";
        };
      };
    };
  };

  networking = {
    networkmanager = {
      wifi.powersave = lib.mkDefault true;
    };
  };
}
