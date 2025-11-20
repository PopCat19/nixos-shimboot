# Helpers Module
#
# Purpose: Import all helper modules
# Dependencies: Various helper modules
# Related: system modules
#
# This module aggregates all helper functionality:
# - Filesystem helpers
# - Permissions helpers
# - Setup helpers
# - Application helpers
{
  imports = [
    ./filesystem-helpers.nix
    ./permissions-helpers.nix
    ./setup-helpers.nix
    ./application-helpers.nix
  ];
}
