# Theme Session Module
#
# Purpose: Configure session variables and utilities
# Dependencies: theme colors, theme_fonts
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
  # Define default variant directly since colors.nix is now a module
  defaultVariant = {
    name = "rose-pine-main";
    gtkThemeName = "Rose-Pine-Main-BL";
    iconTheme = "Rose-Pine";
    cursorTheme = "rose-pine-hyprcursor";
    kvantumTheme = "rose-pine-rose";
  };

  # Define fonts directly since theme_fonts.nix is now a module
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