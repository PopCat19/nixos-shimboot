# Noctalia Home Manager Configuration Module
#
# Purpose: Import and apply Noctalia configuration from dedicated config directory
# Dependencies: inputs.noctalia (flake input), home-manager
# Related: noctalia_config/module.nix
#
# This module:
# - Imports Noctalia home manager module from dedicated config
# - Applies user's personalized settings
# - Configures systemd service for autostart
# - Provides centralized Noctalia configuration management
{
  lib,
  pkgs,
  config,
  system,
  inputs,
  userConfig,
  ...
}: {
  imports = [
    ./module.nix
  ];
}
