{ config, pkgs, lib, ... }:

{
  # Main system configuration imports base configuration and adds optional/user modules
  imports = [
    ../base_configuration/configuration.nix
    ./system_modules/users.nix
    # Add more user/optional system modules here as needed
  ];
}