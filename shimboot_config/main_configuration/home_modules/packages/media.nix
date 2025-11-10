# Media Packages Module
#
# Purpose: Install media playback and creation applications
# Dependencies: None
# Related: packages.nix
#
# This module:
# - Installs media applications
{pkgs, ...}: {
  home.packages = with pkgs; [
    mpv
    audacious
    audacious-plugins
    pureref
    youtube-music
    scrcpy
  ];
}
