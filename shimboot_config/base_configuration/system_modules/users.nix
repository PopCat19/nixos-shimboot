{ config, pkgs, lib, userConfig, ... }:

{
  # User Configuration
  users = {
    users = {
      root = { # Root user configuration
        initialPassword = "nixos-user";
        shell = pkgs.fish;
      };
      "${userConfig.user.username}" = { # Regular user configuration
        isNormalUser = true;
        initialPassword = "nixos-user";
        shell = pkgs.fish;
        extraGroups = userConfig.user.extraGroups;
      };
    };
  };
}