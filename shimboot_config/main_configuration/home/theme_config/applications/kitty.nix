# Kitty Terminal Theme Module
#
# Purpose: Configure Kitty terminal with Rose Pine theme
# Dependencies: theme_config/colors.nix, theme_config/theme_fonts.nix
# Related: kitty.nix
#
# This module:
# - Configures Rose Pine color scheme for Kitty
# - Applies theme fonts and sizing
# - Provides terminal appearance settings
{
  lib,
  pkgs,
  config,
  inputs,
  ...
}: let
  inherit (import ../colors.nix {inherit pkgs config inputs;}) rosePineColors;
  inherit (import ../theme_fonts.nix {inherit pkgs config inputs;}) fonts;
in {
  programs.kitty.settings = {
    font_family = fonts.mono;
    font_size = toString fonts.sizes.kitty;
    window_border_width = 0.5;
    window_margin_width = 8;
    window_padding_width = 12;
    active_border_color = rosePineColors.rose;
    inactive_border_color = rosePineColors.overlay;
    tab_bar_edge = "bottom";
    tab_bar_style = "separator";
    tab_separator = " | ";
    active_tab_foreground = rosePineColors.text;
    active_tab_background = rosePineColors.overlay;
    inactive_tab_foreground = rosePineColors.subtle;
    inactive_tab_background = rosePineColors.base;
    foreground = rosePineColors.text;
    background = rosePineColors.base;
    selection_foreground = rosePineColors.text;
    selection_background = rosePineColors.highlightMed;
    color0 = rosePineColors.overlay;
    color1 = rosePineColors.love;
    color2 = rosePineColors.foam;
    color3 = rosePineColors.gold;
    color4 = rosePineColors.pine;
    color5 = rosePineColors.iris;
    color6 = rosePineColors.rose;
    color7 = rosePineColors.text;
    color8 = rosePineColors.muted;
    color9 = rosePineColors.love;
    color10 = rosePineColors.foam;
    color11 = rosePineColors.gold;
    color12 = rosePineColors.pine;
    color13 = rosePineColors.iris;
    color14 = rosePineColors.rose;
    color15 = rosePineColors.text;
    background_opacity = "0.80";
    dynamic_background_opacity = "yes";
    background_blur = 16;
  };
}