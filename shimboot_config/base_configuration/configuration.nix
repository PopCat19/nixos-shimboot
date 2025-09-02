{ config, pkgs, lib, ... }:

let
  userConfig = import ../user-config.nix { };
in
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
    ./system_modules/audio.nix
    ./system_modules/programs.nix
    ./system_modules/services.nix
  ];

  # Make user config available to modules
  _module.args.userConfig = userConfig;

  nix.settings.trusted-users = lib.mkAfter [ "root" "${userConfig.user.username}" ];
  nix.settings.substituters = lib.mkAfter [ "https://shimboot-systemd-nixos.cachix.org" ];
  nix.settings.trusted-public-keys = lib.mkAfter [ "shimboot-systemd-nixos.cachix.org-1:vCWmEtJq7hA2UOLN0s3njnGs9/EuX06kD7qOJMo2kAA=" ];

  # Enable fish shell since users use it
  programs.fish.enable = true;

  # Preserve state semantics to avoid unexpected changes across upgrades
  system.stateVersion = "24.11";
}