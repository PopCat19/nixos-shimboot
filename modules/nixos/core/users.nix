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
  pkgs,
  lib,
  vars,
  ...
}:
{
  users.mutableUsers = lib.mkDefault true;

  users.users = {
    root = {
      shell = pkgs.${vars.user.shellPackage};
      initialPassword = lib.mkDefault vars.user.initialPassword;
    };
    "${vars.username}" = {
      isNormalUser = true;
      shell = pkgs.${vars.user.shellPackage};
      inherit (vars.user) extraGroups;
      initialPassword = lib.mkDefault vars.user.initialPassword;
    };
  };
}
