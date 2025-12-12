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