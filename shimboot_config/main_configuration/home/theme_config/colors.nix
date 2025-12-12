# Theme Colors Module
#
# Purpose: Define Rose Pine color palette and theme variants
# Dependencies: None
# Related: theme.nix
#
# This module:
# - Defines Rose Pine color palette
# - Provides theme variants and configuration
# - Exports color definitions for other theme components
{...}: let
  rosePineColors = {
    base = "191724";
    surface = "1f1d2e";
    overlay = "26233a";
    muted = "6e6a86";
    subtle = "908caa";
    text = "e0def4";
    love = "eb6f92";
    gold = "f6c177";
    rose = "ebbcba";
    pine = "31748f";
    foam = "9ccfd8";
    iris = "c4a7e7";
    highlightLow = "21202e";
    highlightMed = "403d52";
    highlightHigh = "524f67";
  };

  variants = {
    main = {
      gtkThemeName = "Rose-Pine-Main-BL";
      iconTheme = "Rose-Pine";
      cursorTheme = "rose-pine-hyprcursor";
      kvantumTheme = "rose-pine-rose";
      colors = rosePineColors;
    };
  };

  defaultVariant = variants.main;
in {
  inherit rosePineColors variants defaultVariant;
}