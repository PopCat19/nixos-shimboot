{ config, pkgs, lib, ... }:

{
  imports = [
    ./system_modules/boot.nix
    ./system_modules/networking.nix
    ./system_modules/filesystems.nix
    ./system_modules/packages.nix
    ./system_modules/helpers.nix
    # Use Cachix cache to fetch prebuilt patched systemd
    ./system_modules/cachix-shimboot-systemd.nix
    ./system_modules/security.nix
    ./system_modules/systemd.nix
    ./system_modules/localization.nix
    ./system_modules/hardware.nix
    ./system_modules/power-management.nix
    ./system_modules/display.nix
    ./system_modules/users.nix
  ];

  nix.settings.trusted-users = lib.mkAfter [ "root" "nixos-shimboot" ];

  # Preserve state semantics to avoid unexpected changes across upgrades
  system.stateVersion = "24.11";
}