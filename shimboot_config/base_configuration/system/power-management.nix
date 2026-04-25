# power-management.nix
#
# Purpose: Configure system power and CPU scaling for ChromeOS devices
#
# This module:
# - Enables system-wide power management
# - Configures kernel parameters based on CPU type (Intel/AMD/ARM)
# - Configures auto-cpufreq for dynamic frequency scaling
# - Optimizes WiFi and battery monitoring
#
# CPU-specific configuration:
# - Intel: Uses intel_pstate in passive mode for ChromeOS kernel compatibility
# - AMD: Uses amd-pstate or default cpufreq
# - ARM: Uses cpufreq governors

{ lib, config, ... }:
let
  # Import board database and get current board's config
  boards = import ../../boards/default.nix { inherit lib; };
  inherit (config.shimboot) board;
  boardConfig = boards.${board};
in
{
  # Intel boards: ChromeOS kernel requires passive mode for power management
  # AMD/ARM: No intel_pstate parameter needed
  boot.kernelParams = lib.mkIf (boardConfig.cpu == "intel") (lib.mkForce [ "intel_pstate=passive" ]);

  powerManagement.enable = lib.mkDefault true;

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
