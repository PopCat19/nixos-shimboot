# System Services Module
#
# Purpose: Configure system-wide services
# Dependencies: None
# Related: syncthing.nix
#
# This module:
# - Enables Flatpak
_: {
  services = {
    flatpak.enable = true;
  };
}
