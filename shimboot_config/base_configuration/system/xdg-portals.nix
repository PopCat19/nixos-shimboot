# Desktop Integration Module
#
# Purpose: Configure XDG portals and desktop integration for ChromeOS devices
# Dependencies: xdg-desktop-portal
# Related: hyprland.nix, display-manager.nix
#
# This module:
# - Configures XDG portals for Wayland compatibility
# - Sets up MIME and desktop integration
# - Ensures proper portal service management
{
  pkgs,
  lib,
  ...
}:
{
  xdg.mime.enable = lib.mkDefault true;
  xdg.portal = {
    enable = lib.mkDefault true;
    xdgOpenUsePortal = lib.mkDefault true;
    extraPortals = [
      pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-gtk
    ];
    # choose handlers; Hyprland first, fallback to GTK; default GTK for non-Hyprland
    config = {
      common = {
        default = [ "gtk" ];
      };
      hyprland = {
        default = [
          "hyprland"
          "gtk"
        ];
      };
    };
  };

  # Ensure portal starts with session
  systemd.user.services.xdg-desktop-portal-hyprland = {
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
  };
}
