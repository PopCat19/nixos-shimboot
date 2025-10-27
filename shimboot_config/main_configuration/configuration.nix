# Main Configuration Module
#
# Purpose: Main system configuration combining base and user modules
# Dependencies: base_configuration, user system modules
# Related: base_configuration/configuration.nix, flake.nix
#
# This module:
# - Imports base configuration as foundation
# - Adds user-specific system modules
# - Provides extension point for additional modules
{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ../base_configuration/configuration.nix
    ./system_modules/fonts.nix
    ./system_modules/packages.nix
    ./system_modules/services.nix
  ];
}
