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
{ ... }:
{
  imports = [
    ../../../../base_configuration/configuration.nix
    ./fonts.nix
    ./packages.nix
    ./services.nix
    ./syncthing.nix
    ./stylix.nix
    ./greeter.nix
  ];
}
