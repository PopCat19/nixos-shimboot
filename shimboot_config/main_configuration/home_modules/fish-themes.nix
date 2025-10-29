# Fish Themes Module
#
# Purpose: Configure Fish shell themes
# Dependencies: fish
# Related: fish.nix (in base_configuration)
#
# This module:
# - Adds custom Fish themes to user configuration
# - Does NOT override base Fish configuration
{...}: {
  home.file.".config/fish/themes" = {
    source = ../../fish_themes;
    recursive = true;
  };
}
