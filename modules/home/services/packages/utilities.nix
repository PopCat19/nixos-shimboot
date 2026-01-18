# Utilities Packages Module
#
# Purpose: Install utility applications for productivity
# Dependencies: None
# Related: packages.nix
#
# This module:
# - Installs productivity utility packages
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    eza
    wl-clipboard
    pavucontrol
    playerctl
    localsend
    keepassxc
    vscodium
    zenity
    alejandra
    nixd
    nil
  ];
}
