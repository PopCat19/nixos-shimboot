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

  systemd.user.services.xdg-desktop-portal-hyprland = {
    overrideStrategy = "asDropin";
    wantedBy = [ "hyprland-session.target" ];
    after = [ "hyprland-session.target" ];
    partOf = [ "hyprland-session.target" ];
    unitConfig.ConditionEnvironment = "";
  };

  # Force GTK portal to use Wayland backend
  # GTK prefers X11 when both WAYLAND_DISPLAY and DISPLAY are set
  systemd.user.services.xdg-desktop-portal-gtk = {
    overrideStrategy = "asDropin";
    serviceConfig.Environment = [ "GDK_BACKEND=wayland" ];
    after = [ "hyprland-session.target" ];
    partOf = [ "hyprland-session.target" ];
  };

  # Drop-in for main portal to wait for hyprland backend
  # Prevents race condition where DBus-activated portal starts before backend is ready
  xdg.configFile."systemd/user/xdg-desktop-portal.service.d/override.conf".text = ''
    [Unit]
    After=xdg-desktop-portal-hyprland.service xdg-desktop-portal-gtk.service
    Wants=xdg-desktop-portal-hyprland.service xdg-desktop-portal-gtk.service

    [Service]
    ExecStartPre=/bin/sh -c 'until systemctl --user is-active xdg-desktop-portal-hyprland.service; do sleep 0.5; done'
  '';
}
