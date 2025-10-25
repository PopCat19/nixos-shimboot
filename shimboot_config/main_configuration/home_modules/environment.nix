# Environment Variables Module
#
# Purpose: Configure user-specific environment variables for applications
# Dependencies: userConfig
# Related: fcitx5.nix, theme.nix
#
# This module:
# - Sets environment variables for input methods, themes, and applications
# - Configures Wayland support and GTK/Qt theming
# - Adds local bin to PATH
{
  lib,
  userConfig,
  ...
}: {
  home.sessionVariables = {
    EDITOR = userConfig.defaultApps.editor.command;
    VISUAL = "$EDITOR";
    BROWSER = userConfig.defaultApps.browser.package;
    TERMINAL = userConfig.defaultApps.terminal.command;
    FILE_MANAGER = userConfig.defaultApps.fileManager.package;
    WEBKIT_DISABLE_COMPOSITING_MODE = "1";

    GTK_IM_MODULE = lib.mkForce "fcitx5";
    QT_IM_MODULE = lib.mkForce "fcitx5";
    XMODIFIERS = lib.mkForce "@im=fcitx5";
    MOZ_ENABLE_WAYLAND = "1";
    GTK4_IM_MODULE = "fcitx5";

    GTK_THEME = "Rose-Pine-Main-BL";
    QT_STYLE_OVERRIDE = "kvantum";
    QT_QPA_PLATFORMTHEME = "kvantum";
  };

  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.npm-global/bin"
  ];
}
