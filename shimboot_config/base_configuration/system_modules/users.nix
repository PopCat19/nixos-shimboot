# Users Configuration Module
#
# Purpose: Configure system users for shimboot
# Dependencies: fish
# Related: security.nix, services.nix
#
# This module:
# - Enables mutable users for easy setup
# - Creates root and user accounts with Fish shell
# - Sets initial passwords for bring-up convenience

{
  config,
  pkgs,
  lib,
  userConfig,
  ...
}: {
  users.mutableUsers = lib.mkDefault true;

  users.users = {
    root = {
      shell = pkgs.fish;
      initialPassword = "nixos-shimboot";
    };
    "${userConfig.user.username}" = {
      isNormalUser = true;
      shell = pkgs.fish;
      extraGroups = userConfig.user.extraGroups;
      initialPassword = "nixos-shimboot";
    };
  };
}
