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
  inherit (import ./colors.nix {inherit pkgs config inputs;}) getColor getColorWithOpacity;
  inherit (import ./visual.nix {inherit pkgs config inputs;}) alpha shadows blur gaps radius borders opacity helpers;
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