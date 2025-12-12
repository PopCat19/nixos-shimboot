# Theme dconf Module
#
# Purpose: Configure desktop environment settings via dconf
# Dependencies: theme colors
# Related: theme.nix
#
# This module:
# - Configures GNOME desktop interface settings
# - Sets up theme preferences
# - Manages desktop environment appearance
{
  lib,
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
  
  iconTheme = "Papirus-Dark";
  cursorSize = 24;
in {
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      cursor-theme = defaultVariant.cursorTheme;
      cursor-size = cursorSize;
      gtk-theme = defaultVariant.gtkThemeName;
      icon-theme = iconTheme;
      color-scheme = "prefer-dark";
    };

    "org/gnome/desktop/wm/preferences" = {
      theme = defaultVariant.gtkThemeName;
    };
  };
}