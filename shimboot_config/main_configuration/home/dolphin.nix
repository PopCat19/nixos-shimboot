# Dolphin File Manager Module
#
# Purpose: Configure Dolphin file manager with essential dependencies
# Dependencies: kdePackages.dolphin, userConfig
# Related: kde.nix, theme.nix, bookmarks.nix
#
# This module:
# - Installs Dolphin file manager
# - Sets up essential KDE dependencies
# - Provides core file manager functionality
{
  pkgs,
  config,
  userConfig,
  ...
}: {
  home.packages = with pkgs; [
    kdePackages.dolphin
    kdePackages.ark
    kdePackages.kdegraphics-thumbnailers
    kdePackages.kimageformats
    kdePackages.kio-extras
  ];
}