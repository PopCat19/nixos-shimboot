{
  lib,
  userConfig,
  ...
}: {
  # **ENVIRONMENT VARIABLES**
  # Defines user-specific environment variables for various applications.
  home.sessionVariables = {
    EDITOR = userConfig.defaultApps.editor.command; # Default terminal editor.
    VISUAL = "$EDITOR"; # Visual editor alias.
    BROWSER = userConfig.defaultApps.browser.package; # Default web browser.
    TERMINAL = userConfig.defaultApps.terminal.command;
    FILE_MANAGER = userConfig.defaultApps.fileManager.package;
    # Ensure thumbnails work properly
    WEBKIT_DISABLE_COMPOSITING_MODE = "1";

    # Input Method (fcitx5) with Wayland support
    GTK_IM_MODULE = lib.mkForce "fcitx5";
    QT_IM_MODULE = lib.mkForce "fcitx5";
    XMODIFIERS = lib.mkForce "@im=fcitx5";
    # Firefox/Zen Browser specific for Wayland input method
    MOZ_ENABLE_WAYLAND = "1";
    GTK4_IM_MODULE = "fcitx5";

    # Force GTK and Qt theme variables to ensure Rose Pine is applied
    GTK_THEME = "Rose-Pine-Main-BL";
    QT_STYLE_OVERRIDE = "kvantum";
    QT_QPA_PLATFORMTHEME = "kvantum";
  };

  # Add local bin to PATH
  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.npm-global/bin"
  ];
}
