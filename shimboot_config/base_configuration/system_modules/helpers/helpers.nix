# Helpers Module
#
# Purpose: Import all helper modules
# Dependencies: Various helper modules
# Related: system modules
#
# This module:
# - Imports all helper functionality
# - Provides unified access to helper scripts
# - Manages helper module dependencies
{
  imports = [
    ./filesystem-helpers.nix
    ./permissions-helpers.nix
    ./setup-helpers.nix
    ./application-helpers.nix
  ];
}
