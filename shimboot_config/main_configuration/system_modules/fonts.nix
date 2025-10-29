# Fonts Module
#
# Purpose: Configure system fonts and font rendering
# Dependencies: None
# Related: theme.nix
#
# This module:
# - Disables default font packages
# - Installs Noto fonts, Google fonts, and JetBrains Mono
# - Configures fontconfig with default font families
{pkgs, ...}: {
  fonts.enableDefaultPackages = false;

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-emoji
    noto-fonts-extra

    google-fonts
    mplus-outline-fonts.githubRelease
    jetbrains-mono
    nerd-fonts.jetbrains-mono
  ];

  fonts.fontconfig = {
    enable = true;
    defaultFonts = {
      serif = [
        "Rounded Mplus 1c Medium"
        "Noto Serif"
      ];
      sansSerif = [
        "Rounded Mplus 1c Medium"
        "Noto Sans"
      ];
      monospace = [
        "JetBrainsMono Nerd Font"
        "Noto Sans Mono"
      ];
      emoji = ["Noto Color Emoji"];
    };
  };
}
