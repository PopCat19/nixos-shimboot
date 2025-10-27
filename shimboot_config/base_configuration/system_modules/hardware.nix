# Hardware Configuration Module
#
# Purpose: Configure hardware settings for ChromeOS devices
# Dependencies: linux-firmware, mesa
# Related: boot.nix, display.nix
#
# This module:
# - Enables redistributable firmware for ChromeOS compatibility
# - Configures graphics drivers with 32-bit support
# - Enables Bluetooth with power-on-boot
{
  config,
  pkgs,
  lib,
  userConfig,
  ...
}: {
  hardware = {
    # enableRedistributableFirmware = true;
    graphics = {
      enable = true;
      enable32Bit = lib.mkDefault false;
    };
    bluetooth = {
      enable = lib.mkDefault true;
      powerOnBoot = lib.mkDefault true;
    };
  };
}
