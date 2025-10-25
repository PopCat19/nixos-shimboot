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
{
  config,
  pkgs,
  lib,
  ...
}: {
  powerManagement.enable = true;
  services.thermald.enable = lib.mkDefault true;
  services.upower.enable = lib.mkDefault true;
  services.tlp.enable = lib.mkDefault true;
}
