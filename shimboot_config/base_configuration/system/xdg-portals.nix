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
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
    config = {
      hyprland.default = [ "hyprland" ];
    };
  };

  systemd.user.services.xdg-desktop-portal-hyprland = {
    overrideStrategy = "asDropin";
    wantedBy = [ "hyprland-session.target" ];
    after = [ "hyprland-session.target" ];
    partOf = [ "hyprland-session.target" ];
    unitConfig.ConditionEnvironment = "";
  };

  # Drop-in for main portal to wait for hyprland backend
  # Prevents race condition where DBus-activated portal starts before backend is ready
  systemd.user.services.xdg-desktop-portal = {
    overrideStrategy = "asDropin";
    unitConfig = {
      After = "xdg-desktop-portal-hyprland.service";
      Wants = "xdg-desktop-portal-hyprland.service";
    };
    serviceConfig.ExecStartPre = "/bin/sh -c 'until systemctl --user is-active xdg-desktop-portal-hyprland.service; do sleep 0.5; done'";
  };
}
