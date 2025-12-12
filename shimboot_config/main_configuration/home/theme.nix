# Theme Module
#
# Purpose: Configure Rose Pine theme across GTK, Qt, and desktop environments
# Dependencies: rose-pine packages, inputs
# Related: environment.nix
#
# This module:
# - Imports all theme configuration modules
# - Combines theme components into unified configuration
# - Provides centralized theme management
# - Includes application-specific themes
{
  lib,
  pkgs,
  config,
  inputs,
  userConfig,
  ...
}: {
  imports = [
    ./theme_config/colors.nix
    ./theme_config/visual.nix
    ./theme_config/theme_fonts.nix
    ./theme_config/packages.nix
    ./theme_config/session.nix
    ./theme_config/gtk.nix
    ./theme_config/qt.nix
    ./theme_config/dconf.nix
    ./theme_config/files.nix
    ./theme_config/hyprland.nix
    ./theme_config/window-rules.nix

    # Application-specific themes
    ./theme_config/applications/kitty.nix
    ./theme_config/applications/micro.nix
    ./theme_config/applications/fish.nix
    ./theme_config/applications/fuzzel.nix
    ./theme_config/applications/fcitx5.nix
  ];
}
