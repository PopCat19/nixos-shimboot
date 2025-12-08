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
    syncthing = {
      enable = true;
      openDefaultPorts = true;
      user = "nixos-user";
      group = "users";
      dataDir = "/home/nixos-user/.config/syncthing";
      configDir = "/home/nixos-user/.config/syncthing";
    };
  };
}
