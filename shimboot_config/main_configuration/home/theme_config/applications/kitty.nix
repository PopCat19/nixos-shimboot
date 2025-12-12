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
  inherit (import ../colors.nix {inherit pkgs config inputs;}) getColor;
  inherit (import ../theme_fonts.nix {inherit pkgs config inputs;}) fonts;
in {
  programs.kitty.settings = {
    font_family = fonts.mono;
    font_size = toString fonts.sizes.kitty;
    window_border_width = 0.5;
    window_margin_width = 8;
    window_padding_width = 12;
    active_border_color = getColor "accent";
    inactive_border_color = getColor "surface-variant";
    tab_bar_edge = "bottom";
    tab_bar_style = "separator";
    tab_separator = " | ";
    active_tab_foreground = getColor "text";
    active_tab_background = getColor "surface-variant";
    inactive_tab_foreground = getColor "text-secondary";
    inactive_tab_background = getColor "background";
    foreground = getColor "text";
    background = getColor "background";
    selection_foreground = getColor "text";
    selection_background = getColor "selected";
    color0 = getColor "surface-variant";
    color1 = getColor "error";
    color2 = getColor "success";
    color3 = getColor "warning";
    color4 = getColor "info";
    color5 = getColor "accent";
    color6 = getColor "accent-hover";
    color7 = getColor "text";
    color8 = getColor "text-muted";
    color9 = getColor "error";
    color10 = getColor "success";
    color11 = getColor "warning";
    color12 = getColor "info";
    color13 = getColor "accent";
    color14 = getColor "accent-hover";
    color15 = getColor "text";
    background_opacity = "0.80";
    dynamic_background_opacity = "yes";
    background_blur = 16;
  };
}