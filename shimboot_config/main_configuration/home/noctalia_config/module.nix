# Noctalia Configuration Module
#
# Purpose: Main module for Noctalia configuration
# Dependencies: inputs.noctalia (flake input), home-manager
# Related: home_modules/noctalia.nix
#
# This module:
# - Imports Noctalia home manager module
# - Applies user's personalized settings
# - Configures systemd service for autostart
# - Integrates with the centralized configuration
{
  pkgs,
  config,
  inputs,
  userConfig,
  ...
}: let
  inherit (import ./settings.nix {inherit pkgs config hostname;}) settings;
  hostname = config.networking.hostName or userConfig.host.hostname;
in {
  imports = [
    inputs.noctalia.homeModules.default
  ];

  programs.noctalia-shell = {
    enable = true;
    # Enable systemd service through home manager
    systemd.enable = true;

    inherit ((import ./settings.nix {inherit pkgs config hostname;})) settings;
  };
}
