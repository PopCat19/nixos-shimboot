# Hyprland Theme Module
#
# Purpose: Configure Hyprland window manager with Rose Pine theme
# Dependencies: theme_config/colors.nix, theme_config/visual.nix
# Related: theme.nix
#
# This module:
# - Defines Rose Pine color variables for Hyprland
# - Configures Hyprland appearance and theming
# - Integrates with centralized theme color and visual systems
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
  
  # Define visual properties directly since visual.nix is now a module
  alpha = {
    full = "ff";        # 100% opacity
    high = "e6";        # 90% opacity  
    medium = "cc";      # 80% opacity
    low = "99";         # 60% opacity
    subtle = "80";      # 50% opacity
    faint = "40";       # 25% opacity
  };

  shadows = {
    enabled = false;
    range = 4;
    render_power = 3;
    color = "rgba(${getColor "shadow"}, 0.93)";
    offset = {
      x = 0;
      y = 2;
    };
  };

  blur = {
    enabled = true;
    size = 2;
    passes = 2;
    vibrancy = 0.1696;
  };

  gaps = {
    tiny = 2;
    small = 4;
    medium = 8;
    large = 12;
    huge = 16;
    window = 4;
    workspace = 4;
    panel = 8;
  };

  radius = {
    none = 0;
    tiny = 4;
    small = 8;
    medium = 12;
    large = 16;
    round = 999;
    button = 8;
    card = 12;
    popup = 12;
    window = 12;
    input = 6;
  };

  borders = {
    width = {
      none = 0;
      thin = 1;
      small = 2;
      medium = 3;
      thick = 4;
    };
    default = 2;
  };

  opacity = {
    active = 1.0;
    inactive = 1.0;
    hover = 0.95;
    selected = 0.90;
    disabled = 0.60;
  };

  helpers = {
    hexWithAlpha = colorName: alphaHex: "0x${alphaHex}${getColor colorName}";
  };
in {
  wayland.windowManager.hyprland.settings = {
    # Rose Pine color variables with alpha channel for Hyprland
    "$base" = helpers.hexWithAlpha "background" alpha.full;
    "$surface" = helpers.hexWithAlpha "surface" alpha.full;
    "$overlay" = helpers.hexWithAlpha "surface-variant" alpha.full;
    "$muted" = helpers.hexWithAlpha "text-muted" alpha.full;
    "$subtle" = helpers.hexWithAlpha "text-secondary" alpha.full;
    "$text" = helpers.hexWithAlpha "text" alpha.full;
    "$love" = helpers.hexWithAlpha "error" alpha.full;
    "$gold" = helpers.hexWithAlpha "warning" alpha.full;
    "$rose" = helpers.hexWithAlpha "accent" alpha.full;
    "$pine" = helpers.hexWithAlpha "info" alpha.full;
    "$foam" = helpers.hexWithAlpha "success" alpha.full;
    "$iris" = helpers.hexWithAlpha "accent-hover" alpha.full;
    "$highlightLow" = helpers.hexWithAlpha "shadow" alpha.full;
    "$highlightMed" = helpers.hexWithAlpha "selected" alpha.full;
    "$highlightHigh" = helpers.hexWithAlpha "focus" alpha.full;

    # Window decoration theming using centralized visual properties
    decoration = {
      rounding = radius.window;
      active_opacity = opacity.active;
      inactive_opacity = opacity.inactive;

      shadow = shadows;

      blur = blur;
    };

    # Layout gaps using centralized values
    general = {
      gaps_in = gaps.window;
      gaps_out = gaps.workspace;
      border_size = borders.width.small;
      "col.active_border" = "$rose";
      "col.inactive_border" = "$muted";
    };

    # Layer rules for theme consistency
    layerrule = [
      "blur,bar-0"
      "blur,bar-1"
      "blur,fuzzel"
      "ignorezero,fuzzel"
    ];
  };
}