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
_: {
  # Disable coredumps to save disk space
  systemd.coredump.enable = lib.mkDefault false;

  services.journald.extraConfig = lib.mkDefault ''
    Storage=volatile
    MaxRetentionSec=3day
    RuntimeMaxUse=500M
    RuntimeKeepFree=100M
    Compress=yes
    ForwardToSyslog=no
    ForwardToWall=no
  '';

  services.libinput.enable = lib.mkDefault true;

  services = {
    udisks2.enable = lib.mkDefault true;
    dbus.enable = lib.mkDefault true;
  };
}
