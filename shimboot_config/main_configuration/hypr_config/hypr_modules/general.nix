{
  wayland.windowManager.hyprland.settings = {
    monitor = ",preferred,auto,auto";

    general = {
      gaps_in = 6;
      gaps_out = 12;
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

      shadow = {
        enabled = false;
        range = 4;
        render_power = 3;
        color = "rgba(1a1a1aee)";
      };

      blur = {
        enabled = true;
        size = 3;
        passes = 3;
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
      disable_hyprland_logo = false;
      vfr = true;
    };

    debug = {
      damage_tracking = 0;
    };

    layerrule = [
      "blur,bar-0"
      "blur,bar-1"
      "blur,fuzzel"
      "ignorezero,fuzzel"
    ];
  };
}
