# KDE Applications Module
#
# Purpose: Configure KDE applications and utilities
# Dependencies: KDE packages, userConfig
# Related: dolphin.nix, theme.nix, qt-gtk-config.nix
#
# This module:
# - Installs KDE applications (Gwenview)
# - Configures thumbnail support and theming
# - Provides shared KDE application settings
{
  pkgs,
  config,
  userConfig,
  ...
}: {
  home.packages = with pkgs; [
    kdePackages.gwenview

    ffmpegthumbnailer
    poppler-utils
    libgsf
    webp-pixbuf-loader

    qt6Packages.qtstyleplugin-kvantum
    libsForQt5.qtstyleplugin-kvantum

    papirus-icon-theme
  ];
}
