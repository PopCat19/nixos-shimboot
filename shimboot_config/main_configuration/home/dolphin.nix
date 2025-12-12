# Dolphin File Manager Module
#
# Purpose: Configure Dolphin file manager with essential dependencies
# Dependencies: kdePackages.dolphin, userConfig
# Related: kde.nix, theme.nix, bookmarks.nix
#
# This module:
# - Installs Dolphin file manager
# - Configures thumbnail support and service menus
# - Sets up essential KDE dependencies
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

  home.file.".local/bin/update-thumbnails".text = ''
    #!/usr/bin/env bash
    rm -rf ~/.cache/thumbnails/*
    echo "Thumbnail cache cleared"
  '';

  home.file.".local/bin/update-thumbnails".executable = true;

  home.file.".local/share/kio/servicemenus/open-terminal-here.desktop".text = ''
    [Desktop Entry]
    Type=Service
    ServiceTypes=KonqPopupMenu/Plugin
    MimeType=inode/directory;
    Actions=openTerminalHere;

    [Desktop Action openTerminalHere]
    Name=Open Terminal Here
    Name[en_US]=Open Terminal Here
    Icon=utilities-terminal
    Exec=${userConfig.defaultApps.terminal.command} --working-directory "%f"
  '';
}