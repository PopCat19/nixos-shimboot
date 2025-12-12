# Theme Fonts Module
#
# Purpose: Configure theme-specific font preferences and utilities
# Dependencies: None
# Related: theme.nix
#
# This module:
# - Defines theme font preferences (names and families)
# - Provides font sizing configuration for applications
# - Exports font utilities for other theme components
# - Complements system fonts.nix (which handles package installation)
{...}: {
  fonts = {
    main = "Rounded Mplus 1c Medium";
    mono = "JetBrainsMono Nerd Font";
    sizes = {
      fuzzel = 10;
      kitty = 10;
      gtk = 10;
      fcitx5 = 10;
    };
  };

  mkGtkCss = fontMain: ''
    * {
      font-family: "${fontMain}";
    }
  '';
}