# Hyprland General Settings Module
#
# Purpose: Configure general Hyprland functional settings and appearance
# Dependencies: colors.nix (for theme compatibility)
# Related: animations.nix, window-rules.nix
#
# This module:
# - Sets monitor configuration and gaps
# - Configures window borders and decoration
# - Defines layout and rendering settings
# - References theme colors from centralized configuration
{
  lib,
  ...
}: {
  wayland.windowManager.hyprland.settings = {
    general = {
      gaps_in = 4;
      gaps_out = 4;
      border_size = 2;
      "col.active_border" = "$rose";
      "col.inactive_border" = "$muted";
      resize_on_border = false;
      allow_tearing = false;
      layout = "dwindle";
    };

    decoration = {
      rounding = 12;
      active_opacity = 1.0;
      inactive_opacity = 1.0;

      shadow = lib.mkDefault {
        enabled = false;
        range = 4;
        render_power = 3;
        color = "rgba(1a1a1aee)";
      };
    };

    dwindle = {
      pseudotile = true;
      preserve_split = true;
    };

    master = {
      new_status = "master";
    };

    misc = {
      force_default_wallpaper = -1;
      disable_hyprland_logo = false;
      vfr = true;
    };

    debug = {
      damage_tracking = 0;
    };
  };
}
