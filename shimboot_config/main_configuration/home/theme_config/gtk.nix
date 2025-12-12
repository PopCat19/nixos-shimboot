# Theme GTK Module
#
# Purpose: Configure GTK theming and appearance settings
# Dependencies: theme colors, packages
# Related: theme.nix
#
# This module:
# - Configures GTK theme settings
# - Sets up cursor and icon themes
# - Manages GTK application appearance
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
  cursorPackage = inputs.rose-pine-hyprcursor.packages.${pkgs.system}.default;
  rosePineGtk =
    if builtins.hasAttr "rose-pine-gtk-theme-full" pkgs
    then pkgs.rose-pine-gtk-theme-full
    else if builtins.hasAttr "rose-pine-gtk-theme" pkgs
    then pkgs.rose-pine-gtk-theme
    else null;
in {
  gtk = {
    enable = true;
    cursorTheme = {
      name = defaultVariant.cursorTheme or "rose-pine-hyprcursor";
      size = cursorSize;
      package = cursorPackage;
    };
    theme =
      {
        name = defaultVariant.gtkThemeName;
      }
      // lib.optionalAttrs (rosePineGtk != null) {package = rosePineGtk;};
    iconTheme = {
      name = iconTheme;
      package = pkgs.papirus-icon-theme;
    };
    gtk3.extraConfig = {
      gtk-decoration-layout = "appmenu:minimize,maximize,close";
      gtk-enable-animations = true;
      gtk-primary-button-warps-slider = false;
    };
    gtk4.extraConfig = {
      gtk-decoration-layout = "appmenu:minimize,maximize,close";
      gtk-enable-animations = true;
      gtk-primary-button-warps-slider = false;
    };
  };
}