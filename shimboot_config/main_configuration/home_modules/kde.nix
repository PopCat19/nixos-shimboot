{ pkgs, config, ... }:

{
  # KDE applications and utilities (no desktop environment)
  home.packages = with pkgs; [
    # Dolphin and KDE file management packages
    kdePackages.dolphin
    kdePackages.ark          # Archive manager
    kdePackages.gwenview     # Image viewer
    kdePackages.okular       # Document viewer

    # KDE file system integration and thumbnails
    kdePackages.kdegraphics-thumbnailers
    kdePackages.kimageformats
    kdePackages.kio-extras

    # Additional thumbnail support
    ffmpegthumbnailer        # Video thumbnails
    poppler_utils           # PDF thumbnails
    libgsf                 # OLE/MSO thumbnails
    webp-pixbuf-loader     # WebP image support

    # KDE utilities
    kdePackages.kdialog      # Dialog boxes from shell scripts
    kdePackages.keditbookmarks # Bookmark editor
    kdePackages.kleopatra    # Certificate manager and GUI for GnuPG
    kdePackages.kwalletmanager # Wallet management tool

    # Qt theming
    qt6Packages.qtstyleplugin-kvantum
    libsForQt5.qtstyleplugin-kvantum

    # Papirus icons
    papirus-icon-theme
  ];

  # KDE configuration files - keeping minimal config here, main theme config in theme.nix

  # Qt environment variables for Kvantum
  home.sessionVariables = {
    QT_STYLE_OVERRIDE = "kvantum";
    QT_QPA_PLATFORMTHEME = "kvantum";
    QT_PLATFORM_PLUGIN = "kvantum";
    QT_PLATFORMTHEME = "kvantum";
    XDG_CURRENT_DESKTOP = "KDE";
  };

  # Dolphin file manager bookmarks
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

  # Dolphin configuration - removed to allow Dolphin to manage its own config file
  # This prevents the "configuration file not writable" error

  # Simple thumbnail cache clearing script
  home.file.".local/bin/update-thumbnails".text = ''
    #!/usr/bin/env bash
    # Clear Dolphin thumbnail cache
    rm -rf ~/.cache/thumbnails/*
    echo "Thumbnail cache cleared"
  '';

  home.file.".local/bin/update-thumbnails".executable = true;

  # Dolphin service menu for opening terminal in current directory
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
    Exec=kitty --working-directory "%f"
  '';
}