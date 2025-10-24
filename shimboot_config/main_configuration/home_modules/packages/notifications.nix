# Notifications Packages Module
#
# Purpose: Install notification and dialog utilities
# Dependencies: None
# Related: packages.nix
#
# This module:
# - Installs notification utilities

{pkgs, ...}: {
  home.packages = with pkgs; [
    libnotify
    zenity
  ];
}
