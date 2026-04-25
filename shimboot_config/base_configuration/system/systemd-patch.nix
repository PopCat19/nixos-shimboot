# systemd-patch.nix
#
# Purpose: Configure systemd to use pinned 257.9 with ChromeOS compatibility patch
#
# This module:
# - Sets systemd.package to systemd257 from specialArgs
# - Suppresses unit files missing from systemd 257.9 (added in 258+)
# - Overrides buildPackages.systemd and systemdMinimal to systemd257
#   (nixpkgs uses pkgs.buildPackages.systemd/systemdMinimal for hwdb.bin and
#   udevadm verify, which fail on ChromeOS kernels <5.10)
#
# Systemd version constraint:
# - Ceiling: 257.x (258+ requires kernel >=5.10)
# - Reason: systemd 258+ uses open_tree()/move_mount() syscalls unavailable on
#   older shim kernels (octopus 4.14.x, dedede 5.4.x before certain commits)
# - Ref: https://github.com/ading2210/shimboot/issues/405
{
  systemd257,
  lib,
  pkgs,
  config,
  ...
}:
let
  # systemdMinimal variant of 257.9 for build-time tools (udevadm, systemd-hwdb)
  # Uses the full systemd package since it contains all binaries we need
  systemd257Minimal = systemd257.override {
    withAnalyze = false;
    withApparmor = false;
    withAuditable = false;
    withBootloader = false;
    withCoredump = false;
    withCryptsetup = false;
    withDocumentation = false;
    withEfi = false;
    withFido2 = false;
    withHtmlDocumentation = false;
    withKbd = false;
    withLibiptc = false;
    withLogind = false;
    withMachined = false;
    withNetworkd = false;
    withNspawn = false;
    withOomd = false;
    withPam = false;
    withPasswordQuality = false;
    withPCRE2 = false;
    withPolkit = false;
    withPortabled = false;
    withRemote = false;
    withRepart = false;
    withResolved = false;
    withShell = false;
    withSysusers = false;
    withTimedated = false;
    withTimesyncd = false;
    withTpm2 = false;
    withUkify = false;
    withUlogind = false;
    withVconsole = false;
    withZlib = false;
    withAcl = false;
    withSelinux = false;
    withHomed = false;
    withHomectl = false;
    withSysupdate = false;
    withHibernation = false;
  };
in
{
  systemd.package = lib.mkForce systemd257;

  # Suppress units that don't exist in systemd 257.9 (added in 258+)
  # nixpkgs upstreamSystemUnits includes factory-reset units for systemd 259+
  systemd.suppressedSystemUnits = lib.mkForce [
    "factory-reset.target"
    "systemd-factory-reset-request.service"
    "systemd-factory-reset-reboot.service"
    "factory-reset.target.wants"
  ];

  # Override buildPackages systemd to use 257.9.
  #
  # nixpkgs hardcodes pkgs.buildPackages.systemd (currently 260.x) and
  # pkgs.buildPackages.systemdMinimal for two build-time operations:
  # 1. systemd-hwdb (hwdb.bin generation) — fails with "Protocol driver not attached"
  # 2. udevadm verify (udev rules validation) — fails with "Failed to chase..."
  #
  # Both failures are caused by open_tree()/move_mount() syscalls that require
  # kernel >=5.10, unavailable on ChromeOS shim kernels (5.4.x dedede, 4.14.x octopus).
  #
  # By overlaying buildPackages.systemd and systemdMinimal with systemd257 variants,
  # all build-time systemd tools use the compatible 257.9 version.
  nixpkgs.overlays = [
    (final: prev: {
      buildPackages = prev.buildPackages // {
        systemd = systemd257;
        systemdMinimal = systemd257Minimal;
      };
    })
  ];
}