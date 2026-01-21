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
{ lib, ... }:
let
  userConfig = import ../user-config.nix { };
in
{
  imports = [
    ./system_modules/environment.nix
    ./system_modules/boot.nix
    ./system_modules/networking.nix
    ./system_modules/proxy.nix
    ./system_modules/filesystems.nix
    ./system_modules/packages.nix
    ./system_modules/helpers/helpers.nix
    ./system_modules/security.nix
    ./system_modules/systemd-patch.nix
    ./system_modules/kill-frecon.nix
    ./system_modules/localization.nix
    ./system_modules/hardware.nix
    ./system_modules/power-management.nix
    ./system_modules/hyprland.nix
    ./system_modules/setup-experience.nix
    ./system_modules/display-manager.nix
    ./system_modules/xdg-portals.nix
    ./system_modules/fonts.nix
    ./system_modules/users.nix
    ./system_modules/audio.nix
    ./system_modules/fish.nix
    ./system_modules/services.nix
    ./system_modules/zram.nix
  ];

  _module.args.userConfig = userConfig;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = lib.mkAfter [
      "root"
      "${userConfig.user.username}"
    ];
    substituters = lib.mkAfter [ "https://shimboot-systemd-nixos.cachix.org" ];
    trusted-public-keys = lib.mkAfter [
      "shimboot-systemd-nixos.cachix.org-1:vCWmEtJq7hA2UOLN0s3njnGs9/EuX06kD7qOJMo2kAA="
    ];

    # Enable store optimization at build time
    auto-optimise-store = true; # Hardlink duplicate files
    min-free = 0; # Don't reserve space
  };

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "24.11";
}
