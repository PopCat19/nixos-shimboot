# xdg-portals.nix
#
# Purpose: Configure XDG portals and desktop integration for ChromeOS devices
#
# This module:
# - Configures XDG portals for Wayland compatibility
# - Sets up MIME and desktop integration
# - Ensures proper portal service management
{
  pkgs,
  lib,
  config,
  ...
}:
let
  notHeadless = !config.shimboot.headless;
in
{
  config = lib.mkIf notHeadless {
    xdg.mime.enable = lib.mkDefault true;
    xdg.portal = {
      enable = lib.mkDefault true;
      xdgOpenUsePortal = lib.mkDefault false;
      extraPortals = lib.mkDefault [
        pkgs.xdg-desktop-portal
        pkgs.xdg-desktop-portal-hyprland
        pkgs.xdg-desktop-portal-gtk
      ];
      config = lib.mkDefault {
        common.default = [ "gtk" ];
        hyprland = {
          default = [
            "hyprland"
            "gtk"
          ];
          "org.freedesktop.impl.portal.OpenURI" = [ "gtk" ];
        };
      };
    };

    systemd.user.services.xdg-desktop-portal-hyprland = lib.mkDefault {
      overrideStrategy = "asDropin";
      serviceConfig.Environment = [ "GDK_BACKEND=wayland" ];
      wantedBy = [ "hyprland-session.target" ];
      after = [ "hyprland-session.target" ];
      partOf = [ "hyprland-session.target" ];
      unitConfig.ConditionEnvironment = "";
    };

    systemd.user.services.xdg-desktop-portal = lib.mkDefault {
      overrideStrategy = "asDropin";
      unitConfig = {
        After = "xdg-desktop-portal-hyprland.service";
        Wants = "xdg-desktop-portal-hyprland.service";
      };
      serviceConfig.ExecStartPre = "/bin/sh -c 'until systemctl --user is-active xdg-desktop-portal-hyprland.service; do sleep 0.5; done'";
    };
  };
}
