# Services Module
#
# Purpose: Configure user-level services for media, storage, and utilities
# Dependencies: None
# Related: None
#
# This module:
# - Enables media player control services
# - Configures storage management and clipboard tools
# - Sets up audio effects processing
{ lib, ... }:
{
  services = {
    playerctld.enable = true;
    udiskie.enable = true;
    easyeffects.enable = true;
    cliphist.enable = true;
  };

  systemd.user.services = {
    cliphist = {
      Unit = {
        After = lib.mkForce [ "hyprland-session.target" ];
        PartOf = lib.mkForce [ "hyprland-session.target" ];
      };
      Service = {
        Restart = lib.mkForce "on-failure";
        RestartSec = lib.mkForce "2";
        StartLimitIntervalSec = lib.mkForce "0";
        StartLimitBurst = lib.mkForce "0";
      };
    };
    cliphist-images = {
      Unit = {
        After = lib.mkForce [ "hyprland-session.target" ];
        PartOf = lib.mkForce [ "hyprland-session.target" ];
      };
      Service = {
        Restart = lib.mkForce "on-failure";
        RestartSec = lib.mkForce "2";
        StartLimitIntervalSec = lib.mkForce "0";
        StartLimitBurst = lib.mkForce "0";
      };
    };
  };

  xdg.configFile."systemd/user/xdg-desktop-portal-hyprland.service.d/override.conf".text = ''
    [Unit]
    After=hyprland-session.target
    PartOf=hyprland-session.target
    ConditionEnvironment=
  '';

  xdg.configFile."systemd/user/xdg-desktop-portal.service.d/override.conf".text = ''
    [Unit]
    After=xdg-desktop-portal-hyprland.service xdg-desktop-portal-gtk.service
    Wants=xdg-desktop-portal-hyprland.service xdg-desktop-portal-gtk.service
  '';
}
