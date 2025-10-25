# Permissions Helpers Module
#
# Purpose: Provide utility scripts for fixing permissions
# Dependencies: util-linux
# Related: helpers.nix, security.nix
#
# This module provides:
# - Basic permission fixing utilities
{
  config,
  pkgs,
  lib,
  userConfig,
  ...
}: {
  environment.systemPackages = with pkgs; [
    # Placeholder for future permission utilities
    # bwrap functionality will be handled by steamFHS in main_configuration
  ];
}
