# Media Packages Module
#
# Purpose: Install essential media playback and reference applications
# Dependencies: None
# Related: packages.nix
#
# This module:
# - Installs essential media applications (mpv, pureref, scrcpy)
{pkgs, ...}: {
  home.packages = with pkgs; [
    mpv
    pureref
    scrcpy
  ];
}
