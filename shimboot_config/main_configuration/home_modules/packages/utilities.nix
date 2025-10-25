# Utilities Packages Module
#
# Purpose: Install utility applications for productivity
# Dependencies: None
# Related: packages.nix
#
# This module:
# - Installs utility applications
{pkgs, ...}: {
  home.packages = with pkgs; [
    eza
    wl-clipboard
    pavucontrol
    playerctl
    localsend
    keepassxc
  ];
}
