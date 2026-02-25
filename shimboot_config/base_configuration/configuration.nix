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
#
# Note: userConfig is passed as a module argument
# from the calling configuration (system-configuration.nix or raw-image.nix)
{
  lib,
  pkgs,
  userConfig,
  ...
}:
{
  imports = [
    ./system/environment.nix
    ./system/boot.nix
    ./system/networking.nix
    ./system/proxy.nix
    ./system/filesystems.nix
    ./system/packages.nix
    ./system/helpers/helpers.nix
    ./system/security.nix
    ./system/systemd-patch.nix
    ./system/kill-frecon.nix
    ./system/localization.nix
    ./system/hardware.nix
    ./system/power-management.nix
    ./system/hyprland.nix
    ./system/setup-experience.nix
    ./system/display-manager.nix
    ./system/xdg-portals.nix
    ./system/fonts.nix
    ./system/users.nix
    ./system/audio.nix
    ./system/fish.nix
    ./system/luks2.nix
    ./system/services.nix
    ./system/zram.nix
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

  # Garbage collection: delete generations older than 30 days
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # Keep only 10 system generations before garbage collection runs
  systemd.services.nix-limit-generations = {
    description = "Limit NixOS system generations to 10";
    before = [ "nix-gc.service" ];
    wantedBy = [ "nix-gc.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getBin pkgs.nix}/bin/nix-env --delete-generations +10 -p /nix/var/nix/profiles/system";
    };
  };

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "24.11";
}
