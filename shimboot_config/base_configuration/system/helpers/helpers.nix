# Helpers Module
#
# Purpose: Provide system packages for helper scripts with dependencies
#
# This module:
# - Installs helper scripts as system packages with runtime dependencies
# - Scripts are standalone bash executables
# - No fish dependency required
# - Auto-migrates nixos-shimboot on profile changes
# - Handles hostname and username migrations with state preservation
{ pkgs, userConfig, ... }:
let
  inherit (pkgs) writeShellApplication;
  userData = userConfig.user or userConfig;
  username = userData.username or userConfig.username;

  coreDeps = with pkgs; [
    coreutils
    util-linux
    gnugrep
    gawk
    gnused
    jq
  ];

  expandRootfsDeps =
    coreDeps
    ++ (with pkgs; [
      cloud-utils # growpart
      cryptsetup
      e2fsprogs # resize2fs
    ]);

  fixSteamBwrapDeps =
    coreDeps
    ++ (with pkgs; [
      findutils
    ]);

  bwrapLsmWorkaroundDeps =
    coreDeps
    ++ (with pkgs; [
      bubblewrap
    ]);

  bwrapWrapperDeps =
    coreDeps
    ++ (with pkgs; [
      bubblewrap
    ]);

  setupBwrapPathDeps =
    coreDeps
    ++ (with pkgs; [
      coreutils
    ]);

  setupBwrapWorkaroundDeps =
    coreDeps
    ++ (with pkgs; [
      bubblewrap
    ]);

  setupNixosDeps =
    coreDeps
    ++ (with pkgs; [
      git
      networkmanager
      findutils
      procps
    ]);

  setupNixosConfigDeps =
    coreDeps
    ++ (with pkgs; [
      nix
    ]);

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
      name = "setup-nixos-shimboot";
      runtimeInputs = setupNixosConfigDeps;
      text = builtins.readFile ./setup-nixos-shimboot.sh;
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

  # Auto-migrate nixos-shimboot when switching profiles
  systemd.services.migrate-nixos-shimboot = {
    description = "Migrate nixos-shimboot to current user's home directory";
    wantedBy = [ "multi-user.target" ];
    after = [ "home-manager-${username}.service" ];
    wants = [ "home-manager-${username}.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${
        pkgs.writeShellApplication {
          name = "migrate-nixos-shimboot";
          runtimeInputs = migrateNixosConfigDeps;
          text = builtins.readFile ./migrate-nixos-shimboot.sh;
        }
      }/bin/migrate-nixos-shimboot ${username}";
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
