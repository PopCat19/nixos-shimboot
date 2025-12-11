# Fonts Configuration Module
#
# Purpose: Configure essential fonts and font rendering for main configuration
# Dependencies: noto-fonts, mplus-outline-fonts, jetbrains-mono, nerd-fonts, fontconfig
# Related: packages.nix, theme.nix
#
# This module:
# - Overrides base configuration fonts with essential font selection
# - Installs Noto, Mplus, and JetBrains Mono fonts
# - Configures fontconfig with optimized font family preferences
{pkgs, userConfig, ...}: {
  fonts = {
    # Override base configuration to disable default packages
    enableDefaultPackages = false;

    packages = with pkgs; [
      # Noto fonts for comprehensive coverage
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji

      # Mplus fonts
      mplus-outline-fonts.githubRelease
      
      # Programming fonts
      jetbrains-mono
      nerd-fonts.jetbrains-mono
    ];

    fontconfig = {
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
  };
}
