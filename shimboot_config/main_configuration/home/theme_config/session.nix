# Theme Session Module
#
# Purpose: Configure session variables and utilities
# Dependencies: theme colors, fonts
# Related: theme.nix
#
# This module:
# - Sets up session environment variables
# - Provides theme utility functions
# - Manages desktop session configuration
{
  pkgs,
  config,
  inputs,
  ...
}: let
  inherit (import ./colors.nix {inherit pkgs config inputs;}) defaultVariant;
  inherit (import ./fonts.nix {inherit pkgs config inputs;}) fonts;

  mkSessionVariables = variant: sizes: {
    QT_STYLE_OVERRIDE = "kvantum";
    QT_QPA_PLATFORM = "wayland;xcb";
    GTK_THEME = variant.gtkThemeName;
    GDK_BACKEND = "wayland,x11,*";
    XCURSOR_THEME = variant.cursorTheme;
    QT_QUICK_CONTROLS_STYLE = "Kvantum";
    QT_QUICK_CONTROLS_MATERIAL_THEME = "Dark";
  };

  cursorSize = 24;
in {
  home.sessionVariables =
    mkSessionVariables defaultVariant fonts.sizes
    // {
      XCURSOR_SIZE = builtins.toString cursorSize;
    };
}