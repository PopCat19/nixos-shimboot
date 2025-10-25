# Fcitx5 Input Method Module
#
# Purpose: Configure Fcitx5 for input methods with full Wayland support
# Dependencies: fcitx5 packages
# Related: environment.nix
#
# This module:
# - Enables Fcitx5 with Japanese input support
# - Configures Rose Pine theme
# - Sets up Wayland input method integration
{pkgs, ...}: {
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

  home.file.".config/fcitx5/conf/classicui.conf".text = ''
    Vertical Candidate List=False
    PerScreenDPI=True
    WheelForPaging=True
    Font="Rounded Mplus 1c Medium 11"
    MenuFont="Rounded Mplus 1c Medium 11"
    TrayFont="Rounded Mplus 1c Medium 11"
    TrayOutlineColor=#000000
    TrayTextColor=#ffffff
    PreferTextIcon=False
    ShowLayoutNameInIcon=True
    UseInputMethodLangaugeToDisplayText=True
    Theme=rose-pine
    DarkTheme=rose-pine
    UseDarkTheme=True
    UseAccentColor=True
    EnableTray=True
    ShowPreeditInApplication=False
  '';

  home.file.".local/share/fcitx5/themes/rose-pine".source = "${pkgs.fcitx5-rose-pine}/share/fcitx5/themes/rose-pine";
  home.file.".local/share/fcitx5/themes/rose-pine-dawn".source = "${pkgs.fcitx5-rose-pine}/share/fcitx5/themes/rose-pine-dawn";
  home.file.".local/share/fcitx5/themes/rose-pine-moon".source = "${pkgs.fcitx5-rose-pine}/share/fcitx5/themes/rose-pine-moon";
}
