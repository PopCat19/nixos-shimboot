# System Services Module
#
# Purpose: Configure system-wide services
# Dependencies: None
# Related: syncthing.nix
#
# This module:
# - Enables Flatpak
{
  pkgs,
  userConfig,
  ...
}: {
  services = {
    flatpak.enable = true;
  };
}
