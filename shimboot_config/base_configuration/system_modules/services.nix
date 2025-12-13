# System Services Configuration Module
#
# Purpose: Configure essential system services
# Dependencies: systemd, dbus, polkit
# Related: hardware.nix, security.nix, ssh.nix
#
# This module:
# - Configures systemd journald with size limits
# - Enables libinput for input device handling
# - Sets up udev rules for brightness control
# - Enables storage and D-Bus services
{
  pkgs,
  lib,
  ...
}: {
  services.journald.extraConfig = ''
    MaxRetentionSec=3day
    SystemMaxUse=500M
    SystemKeepFree=100M
    Compress=yes
    ForwardToSyslog=no
    ForwardToWall=no
  '';

  services.libinput.enable = true;

  services = {
    udisks2.enable = true;
    dbus.enable = true;
  };
}
