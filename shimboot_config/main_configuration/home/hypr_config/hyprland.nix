# Hyprland Window Manager
#
# Purpose: Configure Hyprland Wayland compositor with modular settings
# Dependencies: hyprland
# Related: userprefs.conf, wallpaper.nix, modules/*
#
# This module:
# - Enables Hyprland window manager
# - Imports modular configuration files
# - Sources user preferences and monitor configuration
# - Manages shader files and wallpaper directory
{ pkgs, ... }:
{
  imports = [
    ./hypr_modules/colors.nix
    ./hypr_modules/environment.nix
    ./hypr_modules/autostart.nix
    ./hypr_modules/general.nix
    ./hypr_modules/animations.nix
    ./hypr_modules/keybinds.nix
    ./hypr_modules/window-rules.nix
    ./hypr_modules/hyprlock.nix
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
  };
}
