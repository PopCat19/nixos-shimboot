# System Services Module
#
# Purpose: Configure system-wide services
# Dependencies: None
# Related: syncthing.nix
#
# This module:
# - Enables Flatpak service
# - Enables udev service
# - Enables D-Bus service
# - Enables GVFS service
_: {
  services = {
    flatpak.enable = true;
    udev.enable = true;
    dbus.enable = true;
    gvfs.enable = true;
  };
}
