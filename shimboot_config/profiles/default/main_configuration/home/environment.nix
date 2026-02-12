{
  lib,
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

    # Input Method (fcitx5) with Wayland support
    GTK_IM_MODULE = lib.mkForce "fcitx5";
    QT_IM_MODULE = lib.mkForce "fcitx5";
    XMODIFIERS = lib.mkForce "@im=fcitx5";
    # Firefox/Zen Browser specific for Wayland input method
    MOZ_ENABLE_WAYLAND = "1";
    GTK4_IM_MODULE = "fcitx5";

    # GTK/scale defaults
    GDK_SCALE = "1";

    # NixOS configuration paths
    NIXOS_CONFIG_DIR = userConfig.env.NIXOS_CONFIG_DIR;
    NIXOS_PROFILE_DIR = "$NIXOS_CONFIG_DIR/shimboot_config/profiles/${selectedProfile.profile}";
  };

  # Add local bin to PATH
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.npm-global/bin"
  ];
}
