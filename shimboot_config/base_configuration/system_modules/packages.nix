# Minimal System Packages Configuration Module
#
# Purpose: Install absolutely minimal essential system packages only
# Dependencies: Various system utilities
# Related: fish.nix, services.nix, display.nix
#
# This module installs only essential packages:
# - Core utilities (coreutils, util-linux)
# - Text editors (vim, nano, micro)
# - Network tools (wget, curl)
# - System tools (git, btop, file)
# - Documentation disabled to save space
# - Only English locale to reduce size

{
  config,
  pkgs,
  lib,
  ...
}: {
  # Absolutely minimal system packages only
  environment.systemPackages = with pkgs; [
    # Core utilities
    coreutils
    util-linux
    
    # Text editors
    vim
    nano
    micro
    
    # Network tools
    wget
    curl
    
    # System tools
    git
    btop
    file
    
    # These stay for base functionality:
    # - systemd (implicit)
    # - fish (from fish.nix)
    # - LightDM + Hyprland (from display.nix)
  ];
  
  # Disable documentation to save space
  documentation = {
    enable = false;
    doc.enable = false;
    man.enable = false;
    info.enable = false;
    nixos.enable = false;
  };
  
  # Only English locale
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" ];
}
