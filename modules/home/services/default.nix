# User Services Modules
#
# Purpose: Bundle user services and package groups
# Dependencies: All service modules in this directory
# Related: modules/home/core
#
# This bundle:
# - Imports communication packages
# - Imports media packages
# - Imports utility packages
# - Configures additional packages
{ pkgs, ... }:
{
  imports = [
    ./packages/communication.nix
    ./packages/media.nix
    ./packages/utilities.nix
    ./packages.nix
  ];
}
