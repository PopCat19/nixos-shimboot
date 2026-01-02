# Power Management Module
#
# Purpose: Configure system power management and optimization for ChromeOS devices
# Dependencies: auto-cpufreq, upower, networkmanager
# Related: hardware.nix, services.nix
#
# This module:
# - Enables system power management with userspace governor
# - Configures auto-cpufreq for dynamic CPU scaling
# - Enables battery monitoring via upower
# - Configures WiFi power saving through NetworkManager
{lib, ...}: {
  powerManagement = {
    enable = true;
    cpuFreqGovernor = lib.mkDefault "userspace";
  };

  services = {
    upower.enable = lib.mkDefault true;

    auto-cpufreq = {
      enable = lib.mkDefault true;
      settings = {
        battery = {
          governor = lib.mkDefault "schedutil";
          turbo = lib.mkDefault "auto";
        };
        charger = {
          governor = lib.mkDefault "schedutil";
          turbo = lib.mkDefault "auto";
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
