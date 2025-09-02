{ pkgs, config, lib, userConfig, ... }:

{
  # XDG MIME Applications Configuration
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      # Web browsers
      "x-scheme-handler/http" = [ userConfig.defaultApps.browser.desktop ];
      "x-scheme-handler/https" = [ userConfig.defaultApps.browser.desktop ];
      "text/html" = [ userConfig.defaultApps.browser.desktop ];
      "application/xhtml+xml" = [ userConfig.defaultApps.browser.desktop ];

      # Terminal
      "application/x-terminal-emulator" = [ userConfig.defaultApps.terminal.desktop ];
      "x-scheme-handler/terminal" = [ userConfig.defaultApps.terminal.desktop ];

      # Text files
      "text/plain" = [ userConfig.defaultApps.editor.desktop ];
      "text/x-readme" = [ userConfig.defaultApps.editor.desktop ];
      "text/x-log" = [ userConfig.defaultApps.editor.desktop ];
      "application/json" = [ userConfig.defaultApps.editor.desktop ];
      "text/x-python" = [ userConfig.defaultApps.editor.desktop ];
      "text/x-shellscript" = [ userConfig.defaultApps.editor.desktop ];
      "text/x-script" = [ userConfig.defaultApps.editor.desktop ];

      # Images
      "image/jpeg" = [ userConfig.defaultApps.imageViewer.desktop ];
      "image/png" = [ userConfig.defaultApps.imageViewer.desktop ];
      "image/gif" = [ userConfig.defaultApps.imageViewer.desktop ];
      "image/webp" = [ userConfig.defaultApps.imageViewer.desktop ];
      "image/svg+xml" = [ userConfig.defaultApps.imageViewer.desktop ];

      # Videos
      "video/mp4" = [ userConfig.defaultApps.videoPlayer.desktop ];
      "video/mkv" = [ userConfig.defaultApps.videoPlayer.desktop ];
      "video/avi" = [ userConfig.defaultApps.videoPlayer.desktop ];
      "video/webm" = [ userConfig.defaultApps.videoPlayer.desktop ];
      "video/x-matroska" = [ userConfig.defaultApps.videoPlayer.desktop ];

      # Audio
      "audio/mpeg" = [ userConfig.defaultApps.videoPlayer.desktop ];
      "audio/ogg" = [ userConfig.defaultApps.videoPlayer.desktop ];
      "audio/wav" = [ userConfig.defaultApps.videoPlayer.desktop ];
      "audio/flac" = [ userConfig.defaultApps.videoPlayer.desktop ];

      # Archives
      "application/zip" = [ userConfig.defaultApps.archiveManager.desktop ];
      "application/x-tar" = [ userConfig.defaultApps.archiveManager.desktop ];
      "application/x-compressed-tar" = [ userConfig.defaultApps.archiveManager.desktop ];
      "application/x-7z-compressed" = [ userConfig.defaultApps.archiveManager.desktop ];

      # File manager
      "inode/directory" = [ userConfig.defaultApps.fileManager.desktop ];

      # PDF
      "application/pdf" = [ userConfig.defaultApps.pdfViewer.desktop ];
    };
    associations.added = {
      "application/x-terminal-emulator" = [ userConfig.defaultApps.terminal.desktop ];
      "x-scheme-handler/terminal" = [ userConfig.defaultApps.terminal.desktop ];
    };
  };

  # Additional GTK theme files for better consistency
  home.file.".config/gtk-3.0/bookmarks".text = ''
    file://${userConfig.directories.documents} Documents
    file://${userConfig.directories.downloads} Downloads
    file://${userConfig.directories.pictures} Pictures
    file://${userConfig.directories.videos} Videos
    file://${userConfig.directories.music} Music
    file://${userConfig.directories.syncthing} Syncthing Shared
    file://${userConfig.directories.desktop} Desktop
    file://${userConfig.directories.home}/nixos-config nixos-config
    trash:/// Trash
  '';

  # Additional desktop files for better integration
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

  # Nemo file manager configuration with Rose Pine theme and kitty terminal
  home.file.".config/nemo/nemo.conf".text = ''
    [preferences]
    default-folder-viewer=list-view
    show-hidden-files=false
    show-location-entry=false
    start-with-dual-pane=false
    inherit-folder-viewer=true
    ignore-view-metadata=false
    default-sort-order=name
    default-sort-type=ascending
    size-prefixes=base-10
    quick-renames-with-pause-in-between=true
    show-compact-view-icon-toolbar=false
    show-compact-view-icon-toolbar-icons-small=false
    show-compact-view-text-beside-icons=false
    show-full-path-titles=true
    show-new-folder-icon-toolbar=true
    show-open-in-terminal-toolbar=true
    show-reload-icon-toolbar=true
    show-search-icon-toolbar=true
    show-edit-icon-toolbar=false
    show-home-icon-toolbar=true
    show-computer-icon-toolbar=false
    show-up-icon-toolbar=true
    terminal-command=${userConfig.defaultApps.terminal.command}
    close-device-view-on-device-eject=true
    thumbnail-limit=10485760
    executable-text-activation=ask
    show-image-thumbnails=true
    show-thumbnails=true

    [window-state]
    geometry=800x600+0+0
    maximized=false
    sidebar-width=200
    start-with-sidebar=true
    start-with-status-bar=true
    start-with-toolbar=true
    sidebar-bookmark-breakpoint=5

    [list-view]
    default-zoom-level=standard
    default-visible-columns=name,size,type,date_modified
    default-column-order=name,size,type,date_modified

    [icon-view]
    default-zoom-level=standard

    [compact-view]
    default-zoom-level=standard
  '';

  # Nemo actions for better context menu integration
  home.file.".local/share/nemo/actions/open-in-kitty.nemo_action".text = ''
    [Nemo Action]
    Name=Open in Terminal
    Comment=Open a terminal in this location
    Exec=${userConfig.defaultApps.terminal.command} --working-directory %f
    Icon-Name=utilities-terminal
    Selection=None
    Extensions=dir;
  '';

  home.file.".local/share/nemo/actions/edit-as-root.nemo_action".text = ''
    [Nemo Action]
    Name=Edit as Root
    Comment=Edit this file with root privileges
    Exec=pkexec ${userConfig.defaultApps.editor.command} %F
    Icon-Name=accessories-text-editor
    Selection=S
    Extensions=any;
  '';
}