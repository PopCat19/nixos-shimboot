# General Configuration
#
# Purpose: Configure core Hyprland settings including layout, decoration, and behavior
# Dependencies: None
# Related: animations.nix, window-rules.nix
#
# This module:
# - Sets window gaps, borders, and layout behavior
# - Configures decoration (rounding, blur, shadows)
# - Defines dwindle and master layout options
# - Sets performance and debug settings
{
  wayland.windowManager.hyprland.settings = {
    general = {
      gaps_in = 4;
      gaps_out = 4;
      border_size = 2;
      resize_on_border = false;
      allow_tearing = false;
      layout = "dwindle";
    };

    decoration = {
      rounding = 16;
      active_opacity = 1.0;
      inactive_opacity = 1.0;

      shadow = {
        enabled = false;
        range = 4;
        render_power = 3;
      };

      blur = {
        enabled = true;
        size = 2;
        passes = 2;
        vibrancy = 0.1696;
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
      vfr = true;
    };

    debug = {
      damage_tracking = 0;
    };
  };
}
