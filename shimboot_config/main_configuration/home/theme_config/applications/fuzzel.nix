# Fuzzel Launcher Theme Module
#
# Purpose: Configure Fuzzel application launcher with Rose Pine theme
# Dependencies: userConfig, theme_config/theme_fonts.nix, theme_config/colors.nix, theme_config/visual.nix
# Related: fuzzel.nix
#
# This module:
# - Configures Fuzzel with Rose Pine color scheme
# - Applies theme fonts and sizing
# - Sets up keyboard shortcuts and appearance
{
  lib,
  pkgs,
  config,
  inputs,
  userConfig,
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
  
  # Helper function to get color with opacity
  getColorWithOpacity = name: opacity: let
    color = getColor name;
  in "${color}${opacity}";

  # Define visual properties directly since visual.nix is now a module
  alpha = {
    full = "ff";        # 100% opacity
    high = "e6";        # 90% opacity  
    medium = "cc";      # 80% opacity
    low = "99";         # 60% opacity
    subtle = "80";      # 50% opacity
    faint = "40";       # 25% opacity
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

  helpers = {
    hexWithAlpha = colorName: alphaHex: "0x${alphaHex}${getColor colorName}";
  };

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
  programs.fuzzel.settings = {
    main = {
      layer = "overlay";
      placeholder = "Search applications...";
      width = 50;
      lines = 12;
      horizontal-pad = 20;
      vertical-pad = 12;
      inner-pad = 8;
      image-size-ratio = 0.8;
      show-actions = true;
      terminal = userConfig.defaultApps.terminal.command;
      filter-desktop = true;
      icon-theme = "Papirus-Dark";
      icons-enabled = true;
      password-character = "*";
      list-executables-in-path = false;
      font = "${fonts.main}:size=${toString fonts.sizes.fuzzel}";
    };
    colors = {
      background = getColorWithOpacity "background" alpha.high;
      text = getColorWithOpacity "text" alpha.full;
      match = getColorWithOpacity "accent-active" alpha.full;
      selection = getColorWithOpacity "selected" alpha.full;
      selection-text = getColorWithOpacity "text" alpha.full;
      selection-match = getColorWithOpacity "accent-hover" alpha.full;
      border = getColorWithOpacity "accent" alpha.full;
      placeholder = getColorWithOpacity "text-secondary" alpha.full;
    };
    border = {
      radius = radius.medium;
      width = borders.width.small;
    };
    key-bindings = {
      cancel = "Escape Control+c Control+g";
      execute = "Return KP_Enter Control+m";
      execute-or-next = "Tab";
      cursor-left = "Left Control+b";
      cursor-left-word = "Control+Left Mod1+b";
      cursor-right = "Right Control+f";
      cursor-right-word = "Control+Right Mod1+f";
      cursor-home = "Home Control+a";
      cursor-end = "End Control+e";
      delete-prev = "BackSpace Control+h";
      delete-prev-word = "Mod1+BackSpace Control+w";
      delete-next = "Delete Control+d";
      delete-next-word = "Mod1+d";
      prev = "Up Control+p";
      next = "Down Control+n";
      first = "Control+Home";
      last = "Control+End";
    };
  };
}