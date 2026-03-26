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
{ lib, pkgs, ... }:
{
  services = {
    playerctld.enable = true;
    mpris-proxy.enable = true;

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
        ExecStartPre = lib.mkForce "${pkgs.bash}/bin/bash -c 'until systemctl --user show-environment | grep -q WAYLAND_DISPLAY; do sleep 0.5; done'";
        RestartSec = lib.mkForce "3";
        StartLimitIntervalSec = lib.mkForce "0";
      };
    };
    cliphist-images = {
      Unit = {
        After = lib.mkForce [ "hyprland-session.target" ];
        PartOf = lib.mkForce [ "hyprland-session.target" ];
      };
      Service = {
        ExecStartPre = lib.mkForce "${pkgs.bash}/bin/bash -c 'until systemctl --user show-environment | grep -q WAYLAND_DISPLAY; do sleep 0.5; done'";
        RestartSec = lib.mkForce "3";
        StartLimitIntervalSec = lib.mkForce "0";
      };
    };
    xdg-desktop-portal-hyprland = {
      Unit = {
        After = lib.mkForce [ "hyprland-session.target" ];
        PartOf = lib.mkForce [ "hyprland-session.target" ];
        ConditionEnvironment = lib.mkForce "";
      };
    };
    xdg-desktop-portal = {
      Unit = {
        After = lib.mkForce [
          "xdg-desktop-portal-hyprland.service"
          "xdg-desktop-portal-gtk.service"
        ];
        Wants = lib.mkForce [
          "xdg-desktop-portal-hyprland.service"
          "xdg-desktop-portal-gtk.service"
        ];
      };
    };
  };
}
