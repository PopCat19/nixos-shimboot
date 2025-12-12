# Kitty Terminal Module
#
# Purpose: Configure Kitty terminal emulator
# Dependencies: theme_config/applications/kitty.nix
# Related: theme.nix
#
# This module:
# - Imports Kitty theme configuration from theme_config
# - Enables Kitty with Fish shell integration
# - Provides terminal configuration
{lib, pkgs, config, inputs, ...}: {
  imports = [
    ./theme_config/applications/kitty.nix
  ];

  programs.kitty = {
    enable = true;
  };
}
