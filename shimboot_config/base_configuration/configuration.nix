# Base Configuration Module
#
# Purpose: Core NixOS configuration for shimboot base system
#
# This module:
# - Imports all base system modules unconditionally
# - Desktop modules self-gate on shimboot.headless option
# - Configures Nix settings and binary caches
# - Enables Fish shell and unfree packages
# - Sets system state version
# - Sets board from userConfig for hardware-specific configuration
#
# Note: userConfig is passed as a module argument
# from the calling configuration (system-configuration.nix or raw-image.nix)
{
  lib,
  pkgs,
  config,
  userConfig,
  ...
}:
let
  # Core modules - always imported
  coreModules = [
    ../shimboot-options.nix
    ../nix-options.nix
    ./system/environment.nix
    ./system/boot.nix
    ./system/networking.nix
    ./system/filesystems.nix
    ./system/packages.nix
    ./system/helpers/helpers.nix
    ./system/security.nix
    ./system/systemd-patch.nix
    ./system/localization.nix
    ./system/hardware.nix
    ./system/power-management.nix
    ./system/users.nix
    ./system/fish.nix
    ./system/luks2.nix
    ./system/services.nix
    ./system/sshd.nix
    ./system/zram.nix
  ];

  # Desktop modules - gated by shimboot.headless in each module
  desktopModules = [
    ./system/kill-frecon.nix
    ./system/hyprland.nix
    ./system/display-manager.nix
    ./system/xdg-portals.nix
    ./system/fonts.nix
    ./system/audio.nix
  ];

  # Headless-only services - gated by shimboot.headless in each module
  headlessModules = [
    ./system/headless-services.nix
  ];
in
{
  imports = coreModules ++ desktopModules ++ headlessModules;

  # Default to desktop mode when not explicitly set
  shimboot.headless = lib.mkDefault false;

  # Set board from userConfig for hardware-specific configuration
  # This enables conditional driver loading based on ChromeOS board
  shimboot.board = lib.mkDefault userConfig.host.board;

  _module.args.userConfig = userConfig;

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

  system.stateVersion = "24.11";
}
