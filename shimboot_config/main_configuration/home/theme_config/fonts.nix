# Theme Fonts Module
#
# Purpose: Configure theme-specific font settings and utilities
# Dependencies: None
# Related: theme.nix
#
# This module:
# - Defines theme font preferences
# - Provides font sizing configuration
# - Exports font utilities for other theme components
{...}: {
  fonts = {
    main = "Rounded Mplus 1c Medium";
    mono = "JetBrainsMono Nerd Font";
    sizes = {
      fuzzel = 10;
      kitty = 10;
      gtk = 10;
    };
  };

  mkGtkCss = fontMain: ''
    * {
      font-family: "${fontMain}";
    }
  '';
}