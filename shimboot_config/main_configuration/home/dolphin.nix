# Dolphin File Manager Module
#
# Purpose: Configure Dolphin file manager with essential dependencies
# Dependencies: kdePackages.dolphin, userConfig
# Related: kde.nix, stylix.nix, bookmarks.nix
#
# This module:
# - Installs Dolphin file manager
# - Sets up essential KDE dependencies
# - Provides wrapper for Open With menu fix outside KDE
{ pkgs, ... }:
{
  home.file = {
    "bin/dolphin".text = ''
      #!/bin/sh
      export XDG_CONFIG_DIRS="${pkgs.libsForQt5.kservice}/etc/xdg:$XDG_CONFIG_DIRS"
      unset KDE_SESSION_VERSION
      ${pkgs.libsForQt5.kservice}/bin/kbuildsycoca6 --noincremental
      exec ${pkgs.kdePackages.dolphin}/bin/dolphin "$@"
    '';
  };

  home.packages = with pkgs; [
    kdePackages.dolphin
    kdePackages.ark
    kdePackages.kdegraphics-thumbnailers
    kdePackages.kimageformats
    kdePackages.kio-extras
  ];
}
