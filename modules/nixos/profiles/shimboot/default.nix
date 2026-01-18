# Shimboot Profile
#
# Purpose: Shimboot-specific hardware and bootloader configuration
# Dependencies: bootloader.nix
# Related: modules/nixos/core, modules/nixos/hardware
#
# This profile:
# - Configures shimboot bootloader
# - Sets ChromeOS-specific kernel parameters
# - Provides shimboot-specific hardware settings
{
  imports = [
    ./bootloader.nix
  ];
}
