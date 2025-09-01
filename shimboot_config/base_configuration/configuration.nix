{ config, pkgs, lib, ... }:

{
  imports = [
    ./system_modules/boot.nix
    ./system_modules/networking.nix
    ./system_modules/filesystems.nix
    ./system_modules/packages.nix
    ./system_modules/helpers.nix
    ./system_modules/security.nix
    ./system_modules/systemd.nix
    ./system_modules/localization.nix
    ./system_modules/hardware.nix
    ./system_modules/power-management.nix
    ./system_modules/display.nix
  ];

  # Preserve state semantics to avoid unexpected changes across upgrades
  system.stateVersion = "24.11";
}