# Main Configuration Module
#
# Purpose: Main system configuration combining base, system and home modules
# Dependencies: base_configuration, system modules, home modules
# Related: base_configuration/configuration.nix, system/configuration.nix, home/home.nix
#
# This module:
# - Imports base configuration as foundation
# - Adds user-specific system modules
# - Provides extension point for additional modules
{
  config,
  pkgs,
  lib,
  userConfig,
  ...
}: {
  imports = [
    ./system/configuration.nix
  ];
}
