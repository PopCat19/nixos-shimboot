{
  userConfig,
  selectedProfile,
  ...
}:
{
  # **ENVIRONMENT VARIABLES**
  # Defines user-specific environment variables for various applications.
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
    NIXOS_PROFILE_DIR = "${userConfig.env.NIXOS_CONFIG_DIR}/shimboot_config/profiles/${selectedProfile.profile}";
  };

  # Add local bin to PATH
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.npm-global/bin"
  ];
}
