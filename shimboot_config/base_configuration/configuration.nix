# Base Configuration Module
#
# Purpose: Core NixOS configuration for shimboot base system
# Dependencies: All system_modules, user-config.nix
# Related: main_configuration/configuration.nix, user-config.nix
#
# This module:
# - Imports all base system modules
# - Configures Nix settings and binary caches
# - Enables Fish shell and unfree packages
# - Sets system state version
{
  config,
  pkgs,
  lib,
  ...
}: let
  userConfig = import ../user-config.nix {};
in {
  imports = [
    ./system_modules/boot.nix
    ./system_modules/networking.nix
    ./system_modules/filesystems.nix
    ./system_modules/packages.nix
    ./system_modules/helpers/helpers.nix
    ./system_modules/helpers/squashfs-helpers.nix
    ./system_modules/security.nix
    ./system_modules/systemd.nix
    ./system_modules/localization.nix
    ./system_modules/hardware.nix
    ./system_modules/power-management.nix
    ./system_modules/display.nix
    ./system_modules/fonts.nix
    ./system_modules/users.nix
    ./system_modules/audio.nix
    ./system_modules/fish.nix
    ./system_modules/services.nix
    ./system_modules/zram.nix
  ];

  _module.args.userConfig = userConfig;

  nix.settings.trusted-users = lib.mkAfter ["root" "${userConfig.user.username}"];
  nix.settings.substituters = lib.mkAfter ["https://shimboot-systemd-nixos.cachix.org"];
  nix.settings.trusted-public-keys = lib.mkAfter ["shimboot-systemd-nixos.cachix.org-1:vCWmEtJq7hA2UOLN0s3njnGs9/EuX06kD7qOJMo2kAA="];

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "24.11";
}
