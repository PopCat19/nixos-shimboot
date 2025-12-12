# Theme Visual Properties Module
#
# Purpose: Configure centralized visual theme properties and variants
# Dependencies: theme_config/colors.nix
# Related: theme.nix
#
# This module:
# - Defines centralized alpha/opacity values for consistent transparency
# - Provides shadow configuration for visual depth
# - Manages blur settings for visual effects
# - Controls gap sizes for layout spacing
# - Defines border radius values for rounded corners
# - Exports visual utilities for other theme components
{
  pkgs,
  config,
  inputs,
  ...
}: let
  inherit (import ./colors.nix {inherit pkgs config inputs;}) getColor;
in {
  # Alpha/Opacity values for consistent transparency across applications
  alpha = {
    full = "ff";        # 100% opacity
    high = "e6";        # 90% opacity  
    medium = "cc";      # 80% opacity
    low = "99";         # 60% opacity
    subtle = "80";      # 50% opacity
    faint = "40";       # 25% opacity
  };

  # Shadow configuration for visual depth
  shadows = {
    enabled = false;
    range = 4;
    render_power = 3;
    color = "rgba(${getColor "shadow"}, 0.93)"; # ~93% opacity of shadow color
    offset = {
      x = 0;
      y = 2;
    };
  };

  # Blur configuration for visual effects
  blur = {
    enabled = true;
    size = 2;
    passes = 2;
    vibrancy = 0.1696;  # 16.96% vibrancy for subtle effect
  };

  # Gap sizes for consistent layout spacing
  gaps = {
    tiny = 2;
    small = 4;
    medium = 8;
    large = 12;
    huge = 16;
    
    # Default gaps for different contexts
    window = 4;         # gaps_in
    workspace = 4;      # gaps_out
    panel = 8;          # Panel/menu spacing
  };

  # Border radius values for rounded corners
  radius = {
    none = 0;
    tiny = 4;
    small = 8;
    medium = 12;
    large = 16;
    round = 999;        # Fully rounded (circles)
    
    # Default radius for different elements
    button = 8;
    card = 12;
    popup = 12;
    window = 12;
    input = 6;
  };

  # Border configuration
  borders = {
    width = {
      none = 0;
      thin = 1;
      small = 2;
      medium = 3;
      thick = 4;
    };
    
    # Default border width
    default = 2;
  };

  # Opacity settings for different states
  opacity = {
    active = 1.0;       # 100% for active windows
    inactive = 1.0;     # 100% for inactive windows (fully opaque)
    hover = 0.95;       # 95% for hover states
    selected = 0.90;    # 90% for selected states
    disabled = 0.60;    # 60% for disabled elements
  };

  # Helper functions for common operations
  helpers = {
    # Create rgba color string with specific opacity
    rgba = colorName: opacity: "rgba(${getColor colorName}, ${toString opacity})";
    
    # Create hex color with alpha channel
    hexWithAlpha = colorName: alphaHex: "0x${alphaHex}${getColor colorName}";
    
    # Get gap value with fallback
    getGap = context: (gaps.${context} or gaps.small);
    
    # Get radius value with fallback  
    getRadius = context: (radius.${context} or radius.medium);
    
    # Get border width with fallback
    getBorderWidth = context: (borders.width.${context} or borders.width.default);
  };
}