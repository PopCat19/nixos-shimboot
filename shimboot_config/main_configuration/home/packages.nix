# Packages Module
#
# Purpose: Import all package category modules
# Dependencies: All packages/ submodules
# Related: home.nix
#
# This module:
# - Imports package category modules
# - Provides centralized package management
{...}: {
  imports = [
    ./packages/communication.nix
    ./packages/media.nix
    ./packages/utilities.nix
  ];
}
