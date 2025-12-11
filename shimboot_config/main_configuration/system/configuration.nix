# System Configuration Module
#
# Purpose: Main system configuration for user-specific system modules
# Dependencies: base_configuration, user system modules
# Related: base_configuration/configuration.nix, home/home.nix
#
# This module:
# - Imports base configuration as foundation
# - Adds user-specific system modules
# - Provides extension point for additional system modules
{
  config,
  pkgs,
  lib,
  userConfig,
  ...
}: {
  imports = [
    ../../base_configuration/configuration.nix
    ./system_modules/fonts.nix
    ./system_modules/packages.nix
    ./system_modules/services.nix
    ./system_modules/syncthing.nix
  ];
}