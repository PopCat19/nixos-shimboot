{ config, pkgs, lib, ... }:

{
  # User Configuration
  users = {
    users = {
      root = { # Root user configuration
        password = "nixos-user";
        shell = pkgs.bash;
      };
      "nixos-user" = { # Regular user configuration
        isNormalUser = true;
        password = "nixos-user";
        shell = pkgs.bash;
        extraGroups = [ "wheel" "video" "audio" "networkmanager" "tty" ];
      };
    };
    # allowNoPasswordLogin = true; # Allow login without password
  };
}