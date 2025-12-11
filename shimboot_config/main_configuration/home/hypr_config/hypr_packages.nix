# Hyprland Packages Module
#
# Purpose: Install Hyprland ecosystem packages
# Dependencies: None
# Related: hyprland.nix
#
# This module:
# - Installs Hyprland, hyprshade, hyprpaper, hyprpanel, and related tools
{pkgs, ...}: {
  home.packages = with pkgs; [
    hyprland
    hyprshade
    hyprpaper
    hyprpolkitagent
    hyprutils
    hyprpanel
    xdg-desktop-portal-hyprland
  ];
}
