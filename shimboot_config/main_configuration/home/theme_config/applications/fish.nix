# Fish Shell Theme Module
#
# Purpose: Configure Fish shell themes for Rose Pine
# Dependencies: None
# Related: home.nix
#
# This module:
# - Provides Rose Pine Fish shell themes
# - Configures syntax highlighting for Fish
# - Manages theme files for different Rose Pine variants
{...}: {
  home.file.".config/fish/themes" = {
    source = ./fish_themes;
    recursive = true;
  };
}