# Users Configuration Module
#
# Purpose: Configure system users for shimboot
# Dependencies: fish, user-config.nix, openssh
# Related: security.nix, services.nix, user-config.nix
#
# This module:
# - Enables mutable users for easy setup
# - Creates root and user accounts using settings from user-config.nix
# - Sets initial passwords for bring-up convenience
# - Configures SSH authorized keys for passwordless authentication
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
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGiKOcLWZpZToQ3rlBy439vkBMfT+E/JuK1BywvsgiqT popcat19@popcat19-nixos0"
      ];
    };
    "${userConfig.user.username}" = {
      isNormalUser = true;
      shell = pkgs.${userConfig.user.shellPackage};
      extraGroups = userConfig.user.extraGroups;
      initialPassword = lib.mkDefault userConfig.user.initialPassword;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGiKOcLWZpZToQ3rlBy439vkBMfT+E/JuK1BywvsgiqT popcat19@popcat19-nixos0"
      ];
    };
  };
}
