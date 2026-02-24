# Helpers Module
#
# Purpose: Provide system packages for helper scripts with dependencies
# Dependencies: bash, ./*.sh files
# Related: system modules
#
# This module:
# - Installs helper scripts as system packages with runtime dependencies
# - Scripts are standalone bash executables
# - No fish dependency required
# - Auto-migrates nixos-config on profile changes
{ pkgs, lib, userConfig, ... }:
let
  inherit (pkgs) writeShellApplication;

  # Core utilities used by multiple scripts
  coreDeps = with pkgs; [
    coreutils
    util-linux
    gnugrep
    gawk
    gnused
    jq
  ];

  # expand_rootfs dependencies
  expandRootfsDeps =
    coreDeps
    ++ (with pkgs; [
      cloud-utils # growpart
      cryptsetup
      e2fsprogs # resize2fs
    ]);

  # fix-steam-bwrap dependencies
  fixSteamBwrapDeps =
    coreDeps
    ++ (with pkgs; [
      findutils
    ]);

  # setup_nixos dependencies
  setupNixosDeps =
    coreDeps
    ++ (with pkgs; [
      git
      networkmanager
      findutils
      procps
    ]);

  # setup_nixos_config dependencies
  setupNixosConfigDeps =
    coreDeps
    ++ (with pkgs; [
      nix
    ]);

  # migrate_nixos_config dependencies
  migrateNixosConfigDeps = coreDeps;

in
{
  environment.systemPackages = [
    (writeShellApplication {
      name = "fix-steam-bwrap";
      runtimeInputs = fixSteamBwrapDeps;
      text = builtins.readFile ./fix-steam-bwrap.sh;
    })

    (writeShellApplication {
      name = "expand_rootfs";
      runtimeInputs = expandRootfsDeps;
      text = builtins.readFile ./expand_rootfs.sh;
    })

    (writeShellApplication {
      name = "setup_nixos_config";
      runtimeInputs = setupNixosConfigDeps;
      text = builtins.readFile ./setup_nixos_config.sh;
    })

    (writeShellApplication {
      name = "setup_nixos";
      runtimeInputs = setupNixosDeps;
      text = builtins.readFile ./setup_nixos.sh;
    })
  ];

  # Auto-migrate nixos-config when switching profiles
  systemd.services.migrate-nixos-config = {
    description = "Migrate nixos-config to current user's home directory";
    wantedBy = [ "multi-user.target" ];
    after = [ "home-manager-${userConfig.user.username}.service" ];
    wants = [ "home-manager-${userConfig.user.username}.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.writeShellApplication {
        name = "migrate-nixos-config";
        runtimeInputs = migrateNixosConfigDeps;
        text = builtins.readFile ./migrate_nixos_config.sh;
      }}/bin/migrate-nixos-config ${userConfig.user.username}";
      RemainAfterExit = true;
    };
  };
}
