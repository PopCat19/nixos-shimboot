# Hyprland Packages Module
#
# Purpose: Install Hyprland ecosystem packages
# Dependencies: None
# Related: hyprland.nix
#
# This module:
# - Installs Hyprland, hyprshade, hyprpaper, hyprpanel, and related tools
# - Enables hyprscrolling layout plugin
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    hyprshade
    hyprpolkitagent
    hyprutils
    hyprlock
  ];

  wayland.windowManager.hyprland.plugins = [
    pkgs.hyprlandPlugins.hyprscrolling
  ];
}
