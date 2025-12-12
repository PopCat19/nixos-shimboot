# Noctalia Configuration Module
#
# Purpose: Main module for Noctalia configuration replacing HyprPanel
# Dependencies: inputs.noctalia (flake input), home-manager
# Related: home/home.nix
#
# This module:
# - Imports Noctalia home manager module
# - Applies user's personalized settings
# - Configures systemd service for autostart
# - Integrates with the centralized configuration
{
  lib,
  pkgs,
  config,
  system,
  inputs,
  userConfig,
  ...
}: let
  inherit (import ./settings.nix {inherit pkgs;}) settings;
  username = userConfig.user.username;
in {
  imports = [
    inputs.noctalia.homeModules.default
  ];

  programs.noctalia-shell = {
    enable = true;
    systemd.enable = true;

    settings = settings;
  };

  # Configure wallpaper files for noctalia
  home.file = {
    ".cache/noctalia/wallpapers.json".text = builtins.toJSON {
      defaultWallpaper = ../wallpaper/wallpaper0.png;
      wallpapers = {
        "*" = ../wallpaper/wallpaper0.png;
      };
    };
  };
}