# Theme Packages Module
#
# Purpose: Configure theme-related packages and dependencies
# Dependencies: rose-pine packages, inputs
# Related: theme.nix
#
# This module:
# - Installs Rose Pine theme packages
# - Configures Kvantum and GTK theme dependencies
# - Provides theme-specific utilities and tools
{
  lib,
  pkgs,
  config,
  inputs,
  ...
}: let
  system = "x86_64-linux";
in {
  commonPackages = with pkgs; [
    inputs.rose-pine-hyprcursor.packages.${system}.default
    rose-pine-gtk-theme-full
    kdePackages.qtstyleplugin-kvantum
    papirus-icon-theme
    nwg-look
    libsForQt5.qt5ct
    qt6Packages.qt6ct
    polkit_gnome
    gsettings-desktop-schemas
  ];

  home.packages = with pkgs;
    commonPackages
    ++ [
      rose-pine-kvantum
    ];
}