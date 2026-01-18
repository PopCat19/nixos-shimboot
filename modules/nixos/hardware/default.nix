# Hardware Configuration Modules
#
# Purpose: Bundle all hardware-related configuration modules
# Dependencies: All hardware modules in this directory
# Related: modules/nixos/core, modules/nixos/desktop
#
# This bundle:
# - Configures hardware settings
# - Sets up audio
# - Configures power management
# - Enables zram for swap
{
  imports = [
    ./hardware.nix
    ./audio.nix
    ./power-management.nix
    ./zram.nix
  ];
}
