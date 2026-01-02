# Hyprland Window Manager Module
#
# Purpose: Configure Hyprland window manager for ChromeOS devices
# Dependencies: hyprland
# Related: display-manager.nix, packages.nix
#
# This module:
# - Enables Hyprland window manager with XWayland support
# - Configures basic window manager behavior
{
  pkgs,
  lib,
  ...
}: {
  programs.hyprland = {
    enable = lib.mkDefault true;
    xwayland.enable = lib.mkDefault true;
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = lib.mkDefault "1";
  };

  environment.systemPackages = with pkgs; [
    kitty # required for the default Hyprland config
  ];
}
