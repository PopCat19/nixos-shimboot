# Qt/GTK Configuration Module
#
# Purpose: Configure MIME applications, desktop integration, and file manager settings
# Dependencies: userConfig
# Related: theme.nix, kde.nix
#
# This module:
# - Sets up XDG MIME type associations
# - Configures GTK bookmarks and desktop files
# - Sets up file manager integration (Dolphin service menus)
{
  pkgs,
  config,
  lib,
  userConfig,
  ...
}: {
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "x-scheme-handler/http" = [userConfig.defaultApps.browser.desktop];
      "x-scheme-handler/https" = [userConfig.defaultApps.browser.desktop];
      "text/html" = [userConfig.defaultApps.browser.desktop];
      "application/xhtml+xml" = [userConfig.defaultApps.browser.desktop];

      "application/x-terminal-emulator" = [userConfig.defaultApps.terminal.desktop];
      "x-scheme-handler/terminal" = [userConfig.defaultApps.terminal.desktop];

      "text/plain" = [userConfig.defaultApps.editor.desktop];
      "text/x-readme" = [userConfig.defaultApps.editor.desktop];
      "text/x-log" = [userConfig.defaultApps.editor.desktop];
      "application/json" = [userConfig.defaultApps.editor.desktop];
      "text/x-python" = [userConfig.defaultApps.editor.desktop];
      "text/x-shellscript" = [userConfig.defaultApps.editor.desktop];
      "text/x-script" = [userConfig.defaultApps.editor.desktop];

      "image/jpeg" = [userConfig.defaultApps.imageViewer.desktop];
      "image/png" = [userConfig.defaultApps.imageViewer.desktop];
      "image/gif" = [userConfig.defaultApps.imageViewer.desktop];
      "image/webp" = [userConfig.defaultApps.imageViewer.desktop];
      "image/svg+xml" = [userConfig.defaultApps.imageViewer.desktop];

      "video/mp4" = [userConfig.defaultApps.videoPlayer.desktop];
      "video/mkv" = [userConfig.defaultApps.videoPlayer.desktop];
      "video/avi" = [userConfig.defaultApps.videoPlayer.desktop];
      "video/webm" = [userConfig.defaultApps.videoPlayer.desktop];
      "video/x-matroska" = [userConfig.defaultApps.videoPlayer.desktop];

      "audio/mpeg" = [userConfig.defaultApps.videoPlayer.desktop];
      "audio/ogg" = [userConfig.defaultApps.videoPlayer.desktop];
      "audio/wav" = [userConfig.defaultApps.videoPlayer.desktop];
      "audio/flac" = [userConfig.defaultApps.videoPlayer.desktop];

      "application/zip" = [userConfig.defaultApps.archiveManager.desktop];
      "application/x-tar" = [userConfig.defaultApps.archiveManager.desktop];
      "application/x-compressed-tar" = [userConfig.defaultApps.archiveManager.desktop];
      "application/x-7z-compressed" = [userConfig.defaultApps.archiveManager.desktop];

      "inode/directory" = [userConfig.defaultApps.fileManager.desktop];

      "application/pdf" = [userConfig.defaultApps.pdfViewer.desktop];
    };
    associations.added = {
      "application/x-terminal-emulator" = [userConfig.defaultApps.terminal.desktop];
      "x-scheme-handler/terminal" = [userConfig.defaultApps.terminal.desktop];
    };
  };

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

  home.file.".local/share/applications/${userConfig.defaultApps.terminal.package}.desktop".text = ''
    [Desktop Entry]
    Version=1.0
    Type=Application
    Name=${userConfig.defaultApps.terminal.package}
    GenericName=Terminal
    Comment=A modern, hackable, featureful, OpenGL-based terminal emulator
    TryExec=${userConfig.defaultApps.terminal.command}
    Exec=${userConfig.defaultApps.terminal.command}
    Icon=${userConfig.defaultApps.terminal.package}
    Categories=System;TerminalEmulator;
    StartupNotify=true
    MimeType=application/x-terminal-emulator;x-scheme-handler/terminal;
  '';

  home.file.".local/share/applications/${userConfig.defaultApps.editor.package}.desktop".text = ''
    [Desktop Entry]
    Version=1.0
    Type=Application
    Name=${userConfig.defaultApps.editor.package}
    GenericName=Text Editor
    Comment=A modern and intuitive terminal-based text editor
    TryExec=${userConfig.defaultApps.editor.command}
    Exec=${userConfig.defaultApps.editor.command} %F
    Icon=text-editor
    Categories=Utility;TextEditor;Development;
    StartupNotify=false
    MimeType=text/plain;text/x-readme;text/x-log;application/json;text/x-python;text/x-shellscript;text/x-script;
    Terminal=true
  '';

}
