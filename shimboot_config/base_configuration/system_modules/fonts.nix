# Fonts Configuration Module
#
# Purpose: Configure minimal base fonts for system compatibility
# Dependencies: noto-fonts, noto-fonts-emoji, fontconfig
# Related: display.nix
#
# This module:
# - Provides minimal font configuration for base system
# - Installs essential Noto fonts for basic display needs
# - Uses mkDefault to allow override by main configuration
{
  pkgs,
  lib,
  ...
}: {
  fonts = {
    enableDefaultPackages = lib.mkDefault true;

    packages = lib.mkDefault (with pkgs; [
      noto-fonts # Basic Latin/CJK (essential)
      noto-fonts-emoji # Emoji support
    ]);

    fontconfig.defaultFonts = lib.mkDefault {
      serif = ["Noto Serif"];
      sansSerif = ["Noto Sans"];
      monospace = ["Noto Sans Mono"];
      emoji = ["Noto Color Emoji"];
    };
  };
}
