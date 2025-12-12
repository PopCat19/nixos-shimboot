# Fcitx5 Input Method Module
#
# Purpose: Configure Fcitx5 for input methods with full Wayland support
# Dependencies: fcitx5 packages, theme_config/applications/fcitx5.nix
# Related: environment.nix, theme.nix
#
# This module:
# - Imports Fcitx5 theme configuration from theme_config
# - Enables Fcitx5 with Japanese input support
# - Sets up Wayland input method integration
# - Configures input method packages and session variables
{pkgs, ...}: {
  imports = [
    ./theme_config/applications/fcitx5.nix
  ];

  i18n.inputMethod = {
    type = "fcitx5";
    enable = true;
    fcitx5.addons = with pkgs; [
      libsForQt5.fcitx5-qt
      fcitx5-gtk
      fcitx5-mozc
      fcitx5-rose-pine
    ];
  };

  home.sessionVariables = {
    GTK_IM_MODULE = "fcitx5";
    QT_IM_MODULE = "fcitx5";
    XMODIFIERS = "@im=fcitx5";
  };
}
