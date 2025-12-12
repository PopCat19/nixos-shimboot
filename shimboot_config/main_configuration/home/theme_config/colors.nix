# Theme Colors Module
#
# Purpose: Define Rose Pine color palette with matugen compatibility
# Dependencies: None
# Related: theme.nix
#
# This module:
# - Defines Rose Pine color palette in matugen-compatible format
# - Provides theme variants and configuration
# - Exports color definitions for other theme components
# - Follows DRY principle by centralizing all color definitions
{
  lib,
  pkgs,
  config,
  inputs,
  ...
}: let
  # Matugen-compatible color palette
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

  # Theme variants with matugen compatibility
  variants = {
    main = {
      name = "rose-pine-main";
      gtkThemeName = "Rose-Pine-Main-BL";
      iconTheme = "Rose-Pine";
      cursorTheme = "rose-pine-hyprcursor";
      kvantumTheme = "rose-pine-rose";
    };
    
    moon = {
      name = "rose-pine-moon";
      gtkThemeName = "Rose-Pine-Moon-BL";
      iconTheme = "Rose-Pine";
      cursorTheme = "rose-pine-hyprcursor";
      kvantumTheme = "rose-pine-moon";
    };
    
    dawn = {
      name = "rose-pine-dawn";
      gtkThemeName = "Rose-Pine-Dawn-BL";
      iconTheme = "Rose-Pine";
      cursorTheme = "rose-pine-hyprcursor";
      kvantumTheme = "rose-pine-dawn";
    };
  };

  defaultVariant = variants.main;
  
  # Helper function to get color by semantic name
  getColor = name: (rosePineColors.${name} or { name = "000000"; }).name;
in {
  options = {
    theme.colors = lib.mkOption {
      type = lib.types.attrs;
      default = rosePineColors;
      description = "Rose Pine color palette";
    };

    theme.getColor = lib.mkOption {
      type = lib.types.functionTo lib.types.str;
      default = getColor;
      description = "Helper function to get color by semantic name";
    };

    theme.defaultVariant = lib.mkOption {
      type = lib.types.attrs;
      default = defaultVariant;
      description = "Default theme variant";
    };
  };

  config = {
    theme.colors = rosePineColors;
    theme.getColor = getColor;
    theme.defaultVariant = defaultVariant;
  };
}