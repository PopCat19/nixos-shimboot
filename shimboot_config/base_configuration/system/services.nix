# System Services Configuration Module
#
# Purpose: Configure essential system services
# Dependencies: systemd, dbus, polkit
# Related: hardware.nix, security.nix
#
# This module:
# - Disables systemd coredumps to save disk space
# - Configures systemd journald with volatile storage to reduce disk writes
# - Enables libinput for input device handling
# - Sets up udev rules for brightness control
# - Enables storage and D-Bus services
{ lib, ... }:
{
  # Disable coredumps to save disk space
  systemd.coredump.enable = false;

  services.journald.extraConfig = ''
    Storage=volatile
    MaxRetentionSec=3day
    RuntimeMaxUse=500M
    RuntimeKeepFree=100M
    Compress=yes
    ForwardToSyslog=no
    ForwardToWall=no
  '';

  services.libinput.enable = true;

  services = {
    udisks2.enable = true;
    dbus.enable = true;
  };

  systemd.user.services = {
    cliphist = {
      Unit.After = lib.mkForce "hyprland-session.target";
      Unit.PartOf = lib.mkForce "hyprland-session.target";
      serviceConfig.RestartSec = lib.mkForce "3";
      serviceConfig.StartLimitIntervalSec = lib.mkForce "0";
    };
    cliphist-images = {
      Unit.After = lib.mkForce "hyprland-session.target";
      Unit.PartOf = lib.mkForce "hyprland-session.target";
      serviceConfig.RestartSec = lib.mkForce "3";
      serviceConfig.StartLimitIntervalSec = lib.mkForce "0";
    };
    mpris-proxy = {
      Unit.After = lib.mkForce "hyprland-session.target";
      Unit.PartOf = lib.mkForce "hyprland-session.target";
    };
  };
}
