# Main Configuration Module
#
# Purpose: Main system configuration combining base, system and home modules
# Dependencies: base_configuration, system modules, home modules
# Related: base_configuration/configuration.nix, system/configuration.nix, home/home.nix
#
# This module:
# - Imports system modules (which import base configuration)
# - Provides extension point for additional modules
{ ... }:
{
  imports = [
    ./system/configuration.nix
  ];
}
