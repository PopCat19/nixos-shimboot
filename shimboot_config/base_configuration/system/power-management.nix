# power-management.nix
#
# Purpose: Configure system power and CPU scaling for ChromeOS devices
#
# This module:
# - Enables system-wide power management
# - Switches intel_pstate to passive mode to resolve resource busy errors
# - Configures auto-cpufreq for dynamic frequency scaling
# - Optimizes WiFi and battery monitoring

{ lib, ... }:
{
  boot.kernelParams = [ "intel_pstate=passive" ];

  powerManagement.enable = true;

  services = {
    thermald.enable = lib.mkDefault false;

    upower.enable = lib.mkDefault true;

    auto-cpufreq = {
      enable = lib.mkDefault true;
      settings = {
        battery = {
          governor = lib.mkDefault "performance";
          turbo = lib.mkDefault "auto";
        };
        charger = {
          governor = lib.mkDefault "performance";
          turbo = lib.mkDefault "auto";
        };
      };
    };
  };

  networking.networkmanager.wifi.powersave = lib.mkDefault true;
}
