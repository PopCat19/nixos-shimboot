# Minimal System Packages Configuration Module
#
# Purpose: Install absolutely minimal essential system packages only
# Dependencies: Various system utilities
# Related: fish.nix, services.nix, display.nix, security.nix, user-config.nix
#
# This module installs only essential packages:
# - Core utilities (coreutils, util-linux)
# - Text editors (vim, nano, micro)
# - Network tools (wget, curl)
# - System tools (git, btop, file)
# - Documentation disabled to save space
# - Only English locale to reduce size
{ pkgs, userConfig, ... }:
let
  inherit (userConfig.defaultApps) editor;
in
{
  environment.systemPackages = with pkgs; [
    # Text editor (from SoT)
    pkgs.${editor.package}

    # Network tools
    curl

    # System tools
    git
    btop
    fastfetch
    jql
  ];
}
