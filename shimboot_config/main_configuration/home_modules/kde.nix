# KDE Applications Module
#
# Purpose: Configure KDE applications and file management tools
# Dependencies: KDE packages, userConfig
# Related: theme.nix, qt-gtk-config.nix
#
# This module:
# - Installs KDE applications (Dolphin, Gwenview, Okular)
# - Configures file manager bookmarks and service menus
# - Sets up thumbnail support and theming
{
  pkgs,
  config,
  userConfig,
  ...
}: {
  home.packages = with pkgs; [
    kdePackages.dolphin
    kdePackages.ark
    kdePackages.gwenview
    kdePackages.okular

    kdePackages.kdegraphics-thumbnailers
    kdePackages.kimageformats
    kdePackages.kio-extras

    ffmpegthumbnailer
    poppler_utils
    libgsf
    webp-pixbuf-loader

    qt6Packages.qtstyleplugin-kvantum
    libsForQt5.qtstyleplugin-kvantum

    papirus-icon-theme
  ];

  home.file.".local/share/user-places.xbel".text = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE xbel PUBLIC "+//IDN pyxml.sourceforge.net//DTD XML Bookmark Exchange Language 1.0//EN//XML" "http://pyxml.sourceforge.net/topics/dtds/xbel-1.0.dtd">
    <xbel version="1.0">
     <bookmark href="file:///home/${config.home.username}">
      <title>Home</title>
     </bookmark>
     <bookmark href="file:///home/${config.home.username}/Desktop">
      <title>Desktop</title>
     </bookmark>
     <bookmark href="file:///home/${config.home.username}/Documents">
      <title>Documents</title>
     </bookmark>
     <bookmark href="file:///home/${config.home.username}/Downloads">
      <title>Downloads</title>
     </bookmark>
     <bookmark href="file:///home/${config.home.username}/Pictures">
      <title>Pictures</title>
     </bookmark>
     <bookmark href="file:///home/${config.home.username}/Music">
      <title>Music</title>
     </bookmark>
     <bookmark href="file:///home/${config.home.username}/Videos">
      <title>Videos</title>
     </bookmark>
     <bookmark href="file:///home/${config.home.username}/syncthing-shared">
      <title>Syncthing Shared</title>
     </bookmark>
     <bookmark href="file:///home/${config.home.username}/nixos-config">
      <title>nixos-config</title>
     </bookmark>
     <bookmark href="trash:/">
      <title>Trash</title>
     </bookmark>
    </xbel>
  '';

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
