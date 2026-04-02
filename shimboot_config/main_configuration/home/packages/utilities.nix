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
    cliphist
    pavucontrol
    playerctl
    localsend
    keepassxc
    vscodium
    zenity
    nixd
    nil
    biome
    pylint
    ruff
    statix
    deadnix
    nixfmt-tree
    ripgrep

    # Android Development
    scrcpy
    android-tools
  ];
}
