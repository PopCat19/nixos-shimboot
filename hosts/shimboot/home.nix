# Shimboot Home Configuration
#
# Purpose: Home Manager configuration for shimboot host
# Dependencies: modules/home/*
# Related: hosts/shimboot/configuration.nix
#
# This configuration:
# - Imports core home modules
# - Imports CLI tools
# - Imports desktop environment
# - Imports applications
# - Imports user services
{ ... }:
{
  imports = [
    # Core home configuration
    ../../modules/home/core

    # CLI tools
    ../../modules/home/cli

    # Desktop environment
    ../../modules/home/desktop

    # Applications
    ../../modules/home/apps

    # User services
    ../../modules/home/services
  ];

  home.stateVersion = "24.11";
}
