{
  userConfig,
  ...
}:
{
  # **ENVIRONMENT & MIME CONFIG**
  # Defines user-specific environment variables and default applications.
  home.sessionVariables = {
    EDITOR = userConfig.defaultApps.editor.command; # Default terminal editor.
    VISUAL = userConfig.defaultApps.editor.command; # Visual editor alias.
    BROWSER = userConfig.defaultApps.browser.command; # Default web browser.
    TERMINAL = userConfig.defaultApps.terminal.command;
    FILE_MANAGER = userConfig.defaultApps.fileManager.command;
    # Ensure thumbnails work properly
    WEBKIT_DISABLE_COMPOSITING_MODE = "1";

    # GTK/scale defaults
    GDK_SCALE = "1";

    # NixOS configuration paths
    inherit (userConfig.env) NIXOS_CONFIG_DIR;
    NIXOS_CONFIG_PATH = "${userConfig.env.NIXOS_CONFIG_DIR}/shimboot_config";
  };

  # Add local bin to PATH
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.npm-global/bin"
    "$HOME/bin"
  ];

  # Default applications for MIME types
  xdg.mimeApps = {
    enable = true;
    defaultApplications =
      let
        b = userConfig.defaultApps.browser.desktop;
        fm = userConfig.defaultApps.fileManager.desktop;
        img = userConfig.defaultApps.imageViewer.desktop;
        vid = userConfig.defaultApps.videoPlayer.desktop;
        pdf = userConfig.defaultApps.pdfViewer.desktop;
      in
      {
        "text/html" = [ b ];
        "x-scheme-handler/http" = [ b ];
        "x-scheme-handler/https" = [ b ];
        "x-scheme-handler/about" = [ b ];
        "x-scheme-handler/unknown" = [ b ];
        "inode/directory" = [ fm ];
        "image/png" = [ img ];
        "image/jpeg" = [ img ];
        "image/gif" = [ img ];
        "image/webp" = [ img ];
        "video/mp4" = [ vid ];
        "video/mkv" = [ vid ];
        "video/webm" = [ vid ];
        "application/pdf" = [ pdf ];
      };
  };
}
