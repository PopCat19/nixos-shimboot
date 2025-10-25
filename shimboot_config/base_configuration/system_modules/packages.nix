# System Packages Configuration Module
#
# Purpose: Install essential system-wide packages
# Dependencies: Various system utilities
# Related: fish.nix, services.nix
#
# This module installs:
# - Core utilities
# - System monitoring tools
# - Terminal and editor
# - Development tools
{
  config,
  pkgs,
  lib,
  userConfig,
  ...
}: {
  environment.systemPackages = with pkgs; [
    micro
    git
    btop
    kitty
    fastfetch
    curl
    xdg-utils
    fuse
    starship
    gh
    unzip
  ];
}
