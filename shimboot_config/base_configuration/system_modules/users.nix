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
      shell = pkgs.${userConfig.user.shellPackage};
      initialPassword = lib.mkDefault userConfig.user.initialPassword;
    };
    "${userConfig.user.username}" = {
      isNormalUser = true;
      shell = pkgs.${userConfig.user.shellPackage};
      extraGroups = userConfig.user.extraGroups;
      initialPassword = lib.mkDefault userConfig.user.initialPassword;
    };
  };
}
