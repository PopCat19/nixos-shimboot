# Setup Experience Module
#
# Purpose: Launch terminal on first Hyprland login for setup experience
#
# This module:
# - Opens terminal on Hyprland startup
# - Uses fish-greeting for welcome message
# - Uses mkDefault for overridable configuration
{
  lib,
  config,
  ...
}:
let
  notHeadless = !config.shimboot.headless;
in
{
  config = lib.mkIf notHeadless {
    environment.etc = {
      "hyprland.conf".text = ''
        exec-once = kitty
      '';
    };

    programs.hyprland = {
      enable = lib.mkDefault true;
    };
  };
}
