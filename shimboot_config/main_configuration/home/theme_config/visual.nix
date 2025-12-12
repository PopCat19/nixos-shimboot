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
  lib,
  pkgs,
  config,
  inputs,
  ...
}: let
  inherit (import ./colors.nix {inherit pkgs config inputs;}) getColor;
in {
  # Define options for theme properties
  options = {
    theme.alpha = lib.mkOption {
      type = lib.types.attrs;
      default = {
        full = "ff";        # 100% opacity
        high = "e6";        # 90% opacity  
        medium = "cc";      # 80% opacity
        low = "99";         # 60% opacity
        subtle = "80";      # 50% opacity
        faint = "40";       # 25% opacity
      };
      description = "Alpha/Opacity values for consistent transparency across applications";
    };

    theme.shadows = lib.mkOption {
      type = lib.types.attrs;
      default = {
        enabled = false;
        range = 4;
        render_power = 3;
        color = "rgba(${getColor "shadow"}, 0.93)";
        offset = {
          x = 0;
          y = 2;
        };
      };
      description = "Shadow configuration for visual depth";
    };

    theme.blur = lib.mkOption {
      type = lib.types.attrs;
      default = {
        enabled = true;
        size = 2;
        passes = 2;
        vibrancy = 0.1696;
      };
      description = "Blur configuration for visual effects";
    };

    theme.gaps = lib.mkOption {
      type = lib.types.attrs;
      default = {
        tiny = 2;
        small = 4;
        medium = 8;
        large = 12;
        huge = 16;
        window = 4;
        workspace = 4;
        panel = 8;
      };
      description = "Gap sizes for consistent layout spacing";
    };

    theme.radius = lib.mkOption {
      type = lib.types.attrs;
      default = {
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
      description = "Border radius values for rounded corners";
    };

    theme.borders = lib.mkOption {
      type = lib.types.attrs;
      default = {
        width = {
          none = 0;
          thin = 1;
          small = 2;
          medium = 3;
          thick = 4;
        };
        default = 2;
      };
      description = "Border configuration";
    };

    theme.opacity = lib.mkOption {
      type = lib.types.attrs;
      default = {
        active = 1.0;
        inactive = 1.0;
        hover = 0.95;
        selected = 0.90;
        disabled = 0.60;
      };
      description = "Opacity settings for different states";
    };
  };

  config = {
    # Set default values
    theme.alpha = {
      full = "ff";
      high = "e6";
      medium = "cc";
      low = "99";
      subtle = "80";
      faint = "40";
    };

    theme.shadows = {
      enabled = false;
      range = 4;
      render_power = 3;
      color = "rgba(${getColor "shadow"}, 0.93)";
      offset = {
        x = 0;
        y = 2;
      };
    };

    theme.blur = {
      enabled = true;
      size = 2;
      passes = 2;
      vibrancy = 0.1696;
    };

    theme.gaps = {
      tiny = 2;
      small = 4;
      medium = 8;
      large = 12;
      huge = 16;
      window = 4;
      workspace = 4;
      panel = 8;
    };

    theme.radius = {
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

    theme.borders = {
      width = {
        none = 0;
        thin = 1;
        small = 2;
        medium = 3;
        thick = 4;
      };
      default = 2;
    };

    theme.opacity = {
      active = 1.0;
      inactive = 1.0;
      hover = 0.95;
      selected = 0.90;
      disabled = 0.60;
    };
  };
}