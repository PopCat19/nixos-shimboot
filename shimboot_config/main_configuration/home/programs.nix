# Programs Module
#
# Purpose: Configure basic user programs and utilities
# Dependencies: None
# Related: fish.nix
#
# This module:
# - Imports program configurations
_: {
  imports = [
    ./nvim/nvim.nix
  ];
}
