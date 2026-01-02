# Fonts Configuration Helper
#
# Purpose: Extract font configuration for terminal applications
# Dependencies: theme.nix configuration
# Related: theme.nix, kitty.nix, fuzzel.nix
#
# This module:
# - Provides font configuration for terminal applications
# - Extracts fonts from theme configuration
_: {
  fonts = {
    main = "Rounded Mplus 1c Medium";
    mono = "JetBrainsMono Nerd Font";
    sizes = {
      fuzzel = 10;
      kitty = 10;
      gtk = 10;
    };
  };
}
