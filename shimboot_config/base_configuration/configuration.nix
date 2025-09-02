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
    ./system_modules/users.nix
  ];

  nix.settings.trusted-users = lib.mkAfter [ "root" "nixos-shimboot" ];
  nix.settings.substituters = lib.mkAfter [ "https://shimboot-systemd-nixos.cachix.org" ];
  nix.settings.trusted-public-keys = lib.mkAfter [ "shimboot-systemd-nixos.cachix.org-1:vCWmEtJq7hA2UOLN0s3njnGs9/EuX06kD7qOJMo2kAA=" ];

  # Preserve state semantics to avoid unexpected changes across upgrades
  system.stateVersion = "24.11";
}