# Bookmarks Configuration Module
#
# Purpose: Configure file manager bookmarks for GTK and Dolphin
# Dependencies: userConfig
# Related: dolphin.nix
#
# This module:
# - Configures GTK bookmarks for file dialogs
# - Configures Dolphin bookmarks for file manager
# - Provides unified bookmark definitions
{
  config,
  userConfig,
  ...
}: {
  # GTK bookmarks for file dialogs and general file operations
  home.file.".config/gtk-3.0/bookmarks".text = ''
    file://${userConfig.directories.documents} Documents
    file://${userConfig.directories.downloads} Downloads
    file://${userConfig.directories.pictures} Pictures
    file://${userConfig.directories.videos} Videos
    file://${userConfig.directories.music} Music
    file://${userConfig.directories.desktop} Desktop
    file://${userConfig.directories.home}/nixos-config nixos-config
    trash:/// Trash
  '';

  # Dolphin bookmarks for file manager
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
}
