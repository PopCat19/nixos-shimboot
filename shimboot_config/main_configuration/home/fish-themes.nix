# Fish Themes Module
#
# Purpose: Configure Fish shell themes
# Dependencies: theme_config/applications/fish.nix
# Related: fish.nix (in base_configuration)
#
# This module:
# - Imports Fish theme configuration from theme_config
# - Adds custom Fish themes to user configuration
# - Does NOT override base Fish configuration
{...}: {
  imports = [
    ./theme_config/applications/fish.nix
  ];
}
