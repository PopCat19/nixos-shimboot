# Setup Experience Module
#
# Purpose: Launch terminal on first Hyprland login for setup experience
# Dependencies: kitty
# Related: hyprland.nix
#
# This module:
# - Opens terminal on Hyprland startup
# - Uses fish-greeting for welcome message
# - Uses mkDefault for overridable configuration
{ lib, ... }:
{
  environment.etc = {
    "hyprland.conf".text = ''
      exec-once = kitty
    '';
  };

  programs.hyprland = {
    enable = lib.mkDefault true;
  };
}
