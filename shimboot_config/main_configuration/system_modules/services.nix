# System Services Module
#
# Purpose: Configure system-wide services
# Dependencies: None
# Related: None
#
# This module:
# - Enables Flatpak
{pkgs, ...}: {
  services = {
    flatpak.enable = true;
  };
}
