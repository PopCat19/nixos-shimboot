{ config, pkgs, lib, ... }:

{
  # User Configuration (optional / user-facing)
  users = {
    users = {
      root = { # Root user configuration
        initialPassword = "nixos-user";
        shell = pkgs.fish;
      };
      "nixos-user" = { # Regular user configuration
        isNormalUser = true;
        initialPassword = "nixos-user";
        shell = pkgs.fish;
        extraGroups = [ "wheel" "video" "audio" "networkmanager" "tty" ];
      };
    };
    # allowNoPasswordLogin = true; # Allow login without password
  };
}