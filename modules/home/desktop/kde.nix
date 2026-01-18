# KDE Applications Module
#
# Purpose: Configure KDE applications and utilities
# Dependencies: KDE packages, vars
# Related: dolphin.nix, stylix.nix
#
# This module:
# - Installs KDE applications (Gwenview)
# - Configures thumbnail support and theming
# - Provides shared KDE application settings
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    kdePackages.gwenview

    ffmpegthumbnailer
    poppler-utils
    libgsf
    webp-pixbuf-loader
  ];
}
