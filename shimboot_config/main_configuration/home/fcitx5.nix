# Fcitx5 Input Method Module
#
# Purpose: Configure Fcitx5 for Japanese input with full Wayland support
# Dependencies: fcitx5, fcitx5-gtk, fcitx5-mozc
# Related: None
#
# This module:
# - Enables Fcitx5 with mozc Japanese input
# - Sets environment variables for Wayland compatibility
# - Configures GTK/Qt input method modules
{ lib, pkgs, ... }:
{
  i18n.inputMethod = {
    type = "fcitx5";
    enable = true;
    fcitx5.addons = with pkgs; [
      fcitx5-gtk
      fcitx5-mozc
    ];
  };

  home.sessionVariables = {
    GTK_IM_MODULE = lib.mkForce "fcitx5";
    QT_IM_MODULE = lib.mkForce "fcitx5";
    XMODIFIERS = lib.mkForce "@im=fcitx5";
    GTK4_IM_MODULE = "fcitx5";
    MOZ_ENABLE_WAYLAND = "1";
  };
}
