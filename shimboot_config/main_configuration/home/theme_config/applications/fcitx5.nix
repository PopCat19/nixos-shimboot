# Fcitx5 Input Method Theme Module
#
# Purpose: Configure Fcitx5 input method with Rose Pine theme
# Dependencies: theme_config/theme_fonts.nix, theme_config/colors.nix
# Related: fcitx5.nix
#
# This module:
# - Configures Fcitx5 Rose Pine theme
# - Applies theme fonts and colors
# - Sets up input method appearance
{
  lib,
  pkgs,
  config,
  inputs,
  ...
}: let
  inherit (import ../theme_fonts.nix {inherit pkgs config inputs;}) fonts;
  inherit (import ../colors.nix {inherit pkgs config inputs;}) getColor;
in {
  home.file.".config/fcitx5/conf/classicui.conf".text = ''
    Vertical Candidate List=False
    PerScreenDPI=True
    WheelForPaging=True
    Font="${fonts.main} ${toString fonts.sizes.fcitx5}"
    MenuFont="${fonts.main} ${toString fonts.sizes.fcitx5}"
    TrayFont="${fonts.main} ${toString fonts.sizes.fcitx5}"
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