# System Services Configuration Module
#
# Purpose: Configure essential system services
# Dependencies: systemd, dbus, polkit
# Related: hardware.nix, security.nix
#
# This module:
# - Configures systemd journald with size limits
# - Enables libinput for input device handling
# - Sets up udev rules for brightness control
# - Enables storage and D-Bus services

{pkgs, ...}: {
  services.journald.extraConfig = ''
    MaxRetentionSec=3day
    SystemMaxUse=500M
    SystemKeepFree=100M
    Compress=yes
    ForwardToSyslog=no
    ForwardToWall=no
  '';

  services.libinput.enable = true;

  services.udev.extraRules = ''
    SUBSYSTEM=="backlight", ACTION=="add", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness"
    SUBSYSTEM=="backlight", ACTION=="add", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"
    SUBSYSTEM=="leds", ACTION=="add", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/leds/%k/brightness"
    SUBSYSTEM=="leds", ACTION=="add", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/leds/%k/brightness"
  '';

  services = {
    udisks2.enable = true;
    dbus.enable = true;
  };

  security.polkit.enable = true;
  security.rtkit.enable = true;
}
