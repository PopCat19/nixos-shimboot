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
  pkgs,
  config,
  inputs,
  ...
}: let
  inherit (import ./colors.nix {inherit pkgs config inputs;}) defaultVariant;
  inherit (import ./gtk.nix {inherit lib pkgs config inputs;}) gtk;
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