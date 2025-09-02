{ config, pkgs, lib, ... }:

{
  # Package Configuration
  environment.systemPackages = with pkgs; [ # System-wide packages
    micro
    git
    btop
    kitty # Terminal emulator
    fastfetch
    hwinfo
    wget
    curl
    xdg-utils
    shared-mime-info
    fuse
    starship
  ];
}