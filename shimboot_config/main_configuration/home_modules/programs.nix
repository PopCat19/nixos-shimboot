# Programs Module
#
# Purpose: Configure basic user programs and utilities
# Dependencies: None
# Related: fish.nix
#
# This module:
# - Enables Fish shell and Git
# - Provides placeholder for gaming programs (system-level)
{pkgs, ...}: {
  programs.fish.enable = true;

  programs.git = {
    enable = true;
  };
}
