# Fuzzel Launcher Module
#
# Purpose: Configure Fuzzel application launcher
# Dependencies: theme_config/applications/fuzzel.nix
# Related: theme.nix
#
# This module:
# - Imports Fuzzel theme configuration from theme_config
# - Enables Fuzzel application launcher
# - Provides launcher configuration
{...}: {
  imports = [
    ./theme_config/applications/fuzzel.nix
  ];
}