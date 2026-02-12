# System Packages Module
#
# Purpose: Install system-wide packages
# Dependencies: None
# Related: None
#
# This module:
# - Installs system-wide utility packages
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    gh
    ranger
    kdePackages.dolphin
    kdePackages.kio-extras
    usbutils
    android-tools
    tree
  ];
}
