# Users Configuration Module
#
# Purpose: Configure system users for shimboot
# Dependencies: fish, user-config.nix
# Related: security.nix, services.nix, user-config.nix
#
# This module:
# - Enables mutable users for easy setup
# - Creates root and user accounts using settings from user-config.nix
# - Sets initial passwords for bring-up convenience
#
# Supports both shimboot's userConfig.user.* and nixos-config's userConfig.* structures
{
  pkgs,
  lib,
  userConfig,
  ...
}:
let
  userData = userConfig.user or userConfig;
  username = userData.username or userConfig.username;
  shellPackage = userData.shellPackage or "fish";
  initialPassword = userData.initialPassword or "nixos-shimboot";
  extraGroups = userData.extraGroups or [ ];
in
{
  users.mutableUsers = lib.mkDefault true;

  users.users = {
    root = {
      shell = lib.mkForce pkgs.${shellPackage};
      initialPassword = lib.mkDefault initialPassword;
    };
    "${username}" = {
      isNormalUser = lib.mkDefault true;
      shell = lib.mkForce pkgs.${shellPackage};
      extraGroups = lib.mkDefault extraGroups;
      initialPassword = lib.mkDefault initialPassword;
    };
  };
}
