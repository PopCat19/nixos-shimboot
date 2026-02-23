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
}:
let
  inherit (import ./settings.nix { inherit pkgs config userConfig; }) settings;
in
{
  imports = [
    inputs.noctalia.homeModules.default
  ];

  programs.noctalia-shell = {
    enable = true;
    systemd.enable = false;

    inherit ((import ./settings.nix { inherit pkgs config userConfig; })) settings;
  };

  # Custom systemd service with 10-second delay
  systemd.user.services.noctalia-shell = {
    Unit = {
      Description = "Noctalia Shell (with delay)";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      Type = "simple";
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 10";
      ExecStart = "${pkgs.noctalia-shell}/bin/noctalia-shell";
      Restart = "on-failure";
      RestartSec = "5s";
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
