# Micro Text Editor Module
#
# Purpose: Configure Micro text editor
# Dependencies: theme_config/applications/micro.nix
# Related: theme.nix
#
# This module:
# - Imports Micro theme configuration from theme_config
# - Enables Micro editor
# - Provides editor configuration
{...}: {
  imports = [
    ./theme_config/applications/micro.nix
  ];
}
