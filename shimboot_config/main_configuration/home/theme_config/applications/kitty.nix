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
  # Define getColor function directly since colors.nix is now a module
  rosePineColors = {
    # Base colors
    primary = { name = "191724"; description = "Main background"; };
    secondary = { name = "1f1d2e"; description = "Surface elements"; };
    tertiary = { name = "26233a"; description = "Overlay and borders"; };
    
    # Text colors
    text = { name = "e0def4"; description = "Primary text"; };
    text-secondary = { name = "908caa"; description = "Secondary text"; };
    text-muted = { name = "6e6a86"; description = "Muted text"; };
    
    # Accent colors
    accent = { name = "ebbcba"; description = "Primary accent"; };
    accent-hover = { name = "f6c177"; description = "Accent hover state"; };
    accent-active = { name = "eb6f92"; description = "Accent active state"; };
    
    # Semantic colors
    success = { name = "9ccfd8"; description = "Success/positive"; };
    warning = { name = "f6c177"; description = "Warning"; };
    error = { name = "eb6f92"; description = "Error/negative"; };
    info = { name = "c4a7e7"; description = "Information"; };
    
    # Component colors
    background = { name = "191724"; description = "Window background"; };
    surface = { name = "1f1d2e"; description = "Card/surface background"; };
    surface-variant = { name = "26233a"; description = "Variant surface"; };
    
    # Interactive states
    hover = { name = "403d52"; description = "Hover state"; };
    focus = { name = "524f67"; description = "Focus indicator"; };
    selected = { name = "403d52"; description = "Selected state"; };
    disabled = { name = "6e6a86"; description = "Disabled elements"; };
    
    # Border/outline colors
    outline = { name = "26233a"; description = "Default border"; };
    outline-variant = { name = "403d52"; description = "Variant border"; };
    
    # Special purpose colors
    shadow = { name = "21202e"; description = "Shadow color"; };
    scrim = { name = "000000"; description = "Scrim/overlay"; };
  };

  # Helper function to get color by semantic name
  getColor = name: (rosePineColors.${name} or { name = "000000"; }).name;

  # Define fonts directly since theme_fonts.nix is now a module
  fonts = {
    main = "Rounded Mplus 1c Medium";
    mono = "JetBrainsMono Nerd Font";
    sizes = {
      fuzzel = 10;
      kitty = 10;
      gtk = 10;
      fcitx5 = 10;
    };
  };
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