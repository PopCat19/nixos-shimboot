# Hyprland Theme Module
#
# Purpose: Configure Hyprland window manager with Rose Pine theme
# Dependencies: theme_config/colors.nix
# Related: theme.nix
#
# This module:
# - Defines Rose Pine color variables for Hyprland
# - Configures Hyprland appearance and theming
# - Integrates with centralized theme color system
{
  lib,
  pkgs,
  config,
  inputs,
  ...
}: let
  inherit (import ./colors.nix {inherit pkgs config inputs;}) getColor getColorWithOpacity;
in {
  wayland.windowManager.hyprland.settings = {
    # Rose Pine color variables with alpha channel for Hyprland
    "$base" = "0xff${getColor "background"}";
    "$surface" = "0xff${getColor "surface"}";
    "$overlay" = "0xff${getColor "surface-variant"}";
    "$muted" = "0xff${getColor "text-muted"}";
    "$subtle" = "0xff${getColor "text-secondary"}";
    "$text" = "0xff${getColor "text"}";
    "$love" = "0xff${getColor "error"}";
    "$gold" = "0xff${getColor "warning"}";
    "$rose" = "0xff${getColor "accent"}";
    "$pine" = "0xff${getColor "info"}";
    "$foam" = "0xff${getColor "success"}";
    "$iris" = "0xff${getColor "accent-hover"}";
    "$highlightLow" = "0xff${getColor "shadow"}";
    "$highlightMed" = "0xff${getColor "selected"}";
    "$highlightHigh" = "0xff${getColor "focus"}";

    # Window decoration theming
    decoration = {
      rounding = 12;
      active_opacity = 1.0;
      inactive_opacity = 1.0;

      blur = {
        enabled = true;
        size = 2;
        passes = 2;
        vibrancy = 0.1696;
      };
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