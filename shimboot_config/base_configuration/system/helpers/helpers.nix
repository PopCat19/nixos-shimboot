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
# - Handles hostname and username migrations with state preservation
{ pkgs, userConfig, ... }:
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

  # expand-rootfs dependencies
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

  # bwrap-lsm-workaround dependencies
  bwrapLsmWorkaroundDeps =
    coreDeps
    ++ (with pkgs; [
      bubblewrap
    ]);

  # bwrap-wrapper dependencies
  bwrapWrapperDeps =
    coreDeps
    ++ (with pkgs; [
      bubblewrap
    ]);

  # setup-bwrap-path dependencies
  setupBwrapPathDeps =
    coreDeps
    ++ (with pkgs; [
      coreutils
    ]);

  # setup-bwrap-workaround dependencies
  setupBwrapWorkaroundDeps =
    coreDeps
    ++ (with pkgs; [
      bubblewrap
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

  # setup-nixos-config dependencies
  setupNixosConfigDeps =
    coreDeps
    ++ (with pkgs; [
      nix
    ]);

  # migrate-nixos-config dependencies
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
      name = "bwrap-lsm-workaround";
      runtimeInputs = bwrapLsmWorkaroundDeps;
      text = builtins.readFile ./bwrap-lsm-workaround.sh;
    })

    (writeShellApplication {
      name = "bwrap-wrapper";
      runtimeInputs = bwrapWrapperDeps;
      text = builtins.readFile ./bwrap-wrapper.sh;
    })

    (writeShellApplication {
      name = "setup-bwrap-path";
      runtimeInputs = setupBwrapPathDeps;
      text = builtins.readFile ./setup-bwrap-path.sh;
    })

    (writeShellApplication {
      name = "setup-bwrap-workaround";
      runtimeInputs = setupBwrapWorkaroundDeps;
      text = builtins.readFile ./setup-bwrap-workaround.sh;
    })

    (writeShellApplication {
      name = "expand-rootfs";
      runtimeInputs = expandRootfsDeps;
      text = builtins.readFile ./expand-rootfs.sh;
    })

    (writeShellApplication {
      name = "setup-nixos-config";
      runtimeInputs = setupNixosConfigDeps;
      text = builtins.readFile ./setup-nixos-config.sh;
    })

    (writeShellApplication {
      name = "setup-nixos";
      runtimeInputs = setupNixosDeps;
      text = builtins.readFile ./setup-nixos.sh;
    })

    (writeShellApplication {
      name = "migration-status";
      runtimeInputs = coreDeps;
      text = builtins.readFile ./migration-status.sh;
    })
  ];

  # Ensure migration state directory exists
  system.activationScripts.createMigrationStateDir = {
    text = ''
      mkdir -p /var/lib/shimboot-migration
      chmod 755 /var/lib/shimboot-migration
    '';
    deps = [ ];
  };

  # Auto-migrate nixos-config when switching profiles
  systemd.services.migrate-nixos-config = {
    description = "Migrate nixos-config to current user's home directory";
    wantedBy = [ "multi-user.target" ];
    after = [ "home-manager-${userConfig.user.username}.service" ];
    wants = [ "home-manager-${userConfig.user.username}.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${
        pkgs.writeShellApplication {
          name = "migrate-nixos-config";
          runtimeInputs = migrateNixosConfigDeps;
          text = builtins.readFile ./migrate-nixos-config.sh;
        }
      }/bin/migrate-nixos-config ${userConfig.user.username}";
      RemainAfterExit = true;
    };
  };

  # Auto-setup bwrap PATH integration on boot
  systemd.services.setup-bwrap-path = {
    description = "Setup bwrap PATH integration for ChromeOS LSM workaround";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${
        pkgs.writeShellApplication {
          name = "setup-bwrap-path-service";
          runtimeInputs = setupBwrapPathDeps;
          text = builtins.readFile ./setup-bwrap-path.sh;
        }
      }/bin/setup-bwrap-path-service";
      RemainAfterExit = true;
    };
  };
}
