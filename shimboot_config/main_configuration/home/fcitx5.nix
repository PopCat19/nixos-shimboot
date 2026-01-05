# Fcitx5 Input Method Module
#
# Purpose: Configure Fcitx5 for input methods with full Wayland support
# Dependencies: fcitx5 packages
# Related: environment.nix
#
# This module:
# - Enables Fcitx5 with mozc input support
{pkgs, ...}: {
  i18n.inputMethod = {
    type = "fcitx5";
    enable = true;
    waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      fcitx5-gtk
      fcitx5-mozc
    ];
  };
}
