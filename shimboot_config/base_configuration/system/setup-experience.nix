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
        $mainMod = SUPER

        # Terminal
        bind = $mainMod, Q, exec, kitty
        bind = $mainMod, C, killactive
        bind = $mainMod, M, exit

        # Focus
        bind = $mainMod, left, movefocus, l
        bind = $mainMod, right, movefocus, r
        bind = $mainMod, up, movefocus, u
        bind = $mainMod, down, movefocus, d

        # Workspaces
        bind = $mainMod, 1, workspace, 1
        bind = $mainMod, 2, workspace, 2
        bind = $mainMod, 3, workspace, 3
        bind = $mainMod, 4, workspace, 4
        bind = $mainMod, 5, workspace, 5
        bind = $mainMod, 6, workspace, 6
        bind = $mainMod, 7, workspace, 7
        bind = $mainMod, 8, workspace, 8
        bind = $mainMod, 9, workspace, 9
        bind = $mainMod, 0, workspace, 10

        bind = $mainMod SHIFT, 1, movetoworkspace, 1
        bind = $mainMod SHIFT, 2, movetoworkspace, 2
        bind = $mainMod SHIFT, 3, movetoworkspace, 3
        bind = $mainMod SHIFT, 4, movetoworkspace, 4
        bind = $mainMod SHIFT, 5, movetoworkspace, 5
        bind = $mainMod SHIFT, 6, movetoworkspace, 6
        bind = $mainMod SHIFT, 7, movetoworkspace, 7
        bind = $mainMod SHIFT, 8, movetoworkspace, 8
        bind = $mainMod SHIFT, 9, movetoworkspace, 9
        bind = $mainMod SHIFT, 0, movetoworkspace, 10

        exec-once = kitty
      '';
    };

    programs.hyprland = {
      enable = lib.mkDefault true;
    };
  };
}
