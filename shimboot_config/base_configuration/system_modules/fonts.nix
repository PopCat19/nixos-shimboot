# Fonts Configuration Module
#
# Purpose: Configure system fonts for optimal display and compatibility
# Dependencies: noto-fonts, noto-fonts-emoji, fontconfig
# Related: display.nix
#
# This module:
# - Disables default font packages to reduce system size
# - Installs essential Noto fonts for Latin/CJK and emoji support
# - Configures default font families for serif, sans-serif, monospace, and emoji
{
  pkgs,
  lib,
  ...
}: {
  fonts = {
    enableDefaultPackages = lib.mkDefault true;

    packages = with pkgs; [
      noto-fonts # Basic Latin/CJK (essential)
      noto-fonts-emoji # Emoji support
    ];

    fontconfig.defaultFonts = {
      serif = ["Noto Serif"];
      sansSerif = ["Noto Sans"];
      monospace = ["Noto Sans Mono"];
      emoji = ["Noto Color Emoji"];
    };
  };
}
