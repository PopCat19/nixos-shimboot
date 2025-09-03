{ config, pkgs, lib, userConfig, ... }:

{
  # Keep user DB declarative; set plain password during activation (bring-up friendly).
  # For production, replace with hashedPassword/hashedPasswordFile.
  users.mutableUsers = lib.mkDefault false;

  users.users = {
    root = {
      shell = pkgs.fish;
      password = "nixos-shimboot";
    };
    "${userConfig.user.username}" = {
      isNormalUser = true;
      shell = pkgs.fish;
      extraGroups = userConfig.user.extraGroups;
      password = "nixos-shimboot";
    };
  };
}