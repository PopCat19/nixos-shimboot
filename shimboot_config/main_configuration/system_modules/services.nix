# System Services Module
#
# Purpose: Configure system-wide services
# Dependencies: None
# Related: None
#
# This module:
# - Enables Flatpak and adds Flathub repository
{pkgs, ...}: {
  services = {
    flatpak.enable = true;
  };

  systemd.services.flatpak-repo = {
    wantedBy = ["multi-user.target"];
    path = [pkgs.flatpak];
    script = ''
      flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    '';
  };
}
