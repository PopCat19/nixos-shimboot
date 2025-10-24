# System Packages Configuration Module
#
# Purpose: Install essential system-wide packages
# Dependencies: Various system utilities
# Related: fish.nix, services.nix
#
# This module installs:
# - Core utilities (git, wget, curl)
# - System monitoring tools (btop, fastfetch, hwinfo)
# - Terminal and editor (kitty, micro)
# - Development tools (python, gh, unzip)

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
    hwinfo
    wget
    curl
    xdg-utils
    shared-mime-info
    fuse
    starship
    python313Packages.pip
    gh
    unzip
  ];
}
