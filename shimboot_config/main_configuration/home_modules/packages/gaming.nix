# Gaming Packages Module
#
# Purpose: Install gaming applications and launchers
# Dependencies: None
# Related: packages.nix
#
# This module:
# - Installs gaming applications
{pkgs, ...}: {
  home.packages = with pkgs; [
    lutris
    osu-lazer-bin
  ];
}
