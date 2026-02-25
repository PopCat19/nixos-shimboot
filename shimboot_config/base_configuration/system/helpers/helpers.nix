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

  # migrate_hostname dependencies
  migrateHostnameDeps =
    coreDeps
    ++ (with pkgs; [
      systemd # hostnamectl
    ]);

  # migrate_username dependencies
  migrateUsernameDeps =
    coreDeps
    ++ (with pkgs; [
      shadow # usermod, groupmod
      findutils
    ]);

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

    (writeShellApplication {
      name = "migrate-hostname";
      runtimeInputs = migrateHostnameDeps;
      text = builtins.readFile ./migrate-hostname.sh;
    })

    (writeShellApplication {
      name = "migrate-username";
      runtimeInputs = migrateUsernameDeps;
      text = builtins.readFile ./migrate-username.sh;
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

  # Auto-migrate hostname when configuration changes
  systemd.services.migrate-hostname = {
    description = "Migrate hostname while preserving previous state";
    wantedBy = [ "multi-user.target" ];
    before = [ "network.target" ];
    after = [ "systemd-hostnamed.service" ];
    wants = [ "systemd-hostnamed.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${
        pkgs.writeShellApplication {
          name = "migrate-hostname-service";
          runtimeInputs = migrateHostnameDeps;
          text = builtins.readFile ./migrate-hostname.sh;
        }
      }/bin/migrate-hostname-service ${userConfig.host.hostname}";
      RemainAfterExit = true;
    };
  };

  # Auto-migrate username when configuration changes
  # Note: This runs early but only performs migration if username actually changed
  systemd.services.migrate-username = {
    description = "Migrate username while preserving user data";
    wantedBy = [ "multi-user.target" ];
    before = [ "display-manager.service" ];
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${
        pkgs.writeShellApplication {
          name = "migrate-username-service";
          runtimeInputs = migrateUsernameDeps;
          text = builtins.readFile ./migrate-username.sh;
        }
      }/bin/migrate-username-service ${userConfig.user.username}";
      RemainAfterExit = true;
    };
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
          text = builtins.readFile ./migrate_nixos_config.sh;
        }
      }/bin/migrate-nixos-config ${userConfig.user.username}";
      RemainAfterExit = true;
    };
  };
}
