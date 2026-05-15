# nh.nix
#
# Purpose: Configure nh (nix-community/nh) as the Nix CLI helper
#
# This module:
# - Installs nh package and sets NH_FLAKE env var
# - Runs nh clean all timer for system + user profile closures
# - Grants passwordless sudo for nh os subcommands
# - Supports both flat ({username}) and nested ({user.username}) userConfig shapes
{ lib, userConfig, ... }:
let
  # Support both flat and nested userConfig layouts
  userData = userConfig.user or userConfig;
  username = userData.username or userConfig.username;
in
{
  programs.nh = {
    enable = true;
    flake = userConfig.env.NIXOS_CONFIG_DIR;

    clean = {
      enable = true;
      extraArgs = "--keep-since 30d --keep 5";
    };
  };

  security.sudo.extraRules = [
    {
      users = [ username ];
      commands = [
        {
          command = "/run/current-system/sw/bin/nh";
          options = [ "SETENV" "NOPASSWD" ];
        }
        {
          command = "${userConfig.env.NIXOS_CONFIG_DIR}/result/sw/bin/nh";
          options = [ "SETENV" "NOPASSWD" ];
        }
      ];
    }
  ];
}
