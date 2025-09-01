{ config, pkgs, lib, ... }:

{
  # Optional/user-specific system configuration
  imports = [
    ./system_modules/users.nix
    # Add more user/optional system modules here as needed
  ];
}