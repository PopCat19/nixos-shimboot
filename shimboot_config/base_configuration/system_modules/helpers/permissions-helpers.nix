# Permissions Helpers Module
#
# Purpose: Provide utility scripts for fixing permissions
# Dependencies: util-linux
# Related: helpers.nix, security.nix
#
# This module:
# - Provides permission fixing utilities
# - Handles security wrapper configurations
# - Maintains proper access controls
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # Placeholder for future permission utilities
    # bwrap functionality will be handled by steamFHS in main_configuration
  ];
}
