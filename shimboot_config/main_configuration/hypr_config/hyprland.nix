# Hyprland Configuration Module
#
# Purpose: Configure Hyprland window manager and related settings
# Dependencies: hypr_modules, wallpaper.nix
# Related: hypr_packages.nix, display.nix
#
# This module:
# - Imports all Hyprland configuration modules
# - Sets up configuration files and shaders
# - Configures monitors, wallpaper, and user preferences

{
  config,
  lib,
  pkgs,
  ...
}: let
  wallpaper = import ./wallpaper.nix {inherit lib pkgs;};
in {
  imports = [
    ./hypr_modules/colors.nix
    ./hypr_modules/environment.nix
    ./hypr_modules/autostart.nix
    ./hypr_modules/general.nix
    ./hypr_modules/animations.nix
    ./hypr_modules/keybinds.nix
    ./hypr_modules/window-rules.nix
    ./hypr_modules/hyprlock.nix
    ./hypr_modules/fuzzel.nix
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    package = pkgs.hyprland;

    settings = {
      source = [
        "~/.config/hypr/monitors.conf"
        "~/.config/hypr/userprefs.conf"
      ];
    };
  };

  home.file = {
    ".config/hypr/monitors.conf".source = ./monitors.conf;
    ".config/hypr/userprefs.conf".source = ./userprefs.conf;
    ".config/hypr/hyprpaper.conf".source = wallpaper.hyprpaperConf;
    ".config/hypr/shaders" = {
      source = ./shaders;
      recursive = true;
    };
  };
}
