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
  ...
}:
{
  systemd.package = lib.mkForce systemd257;

  # Suppress units that don't exist in systemd 257.9 (added in 258+)
  # nixpkgs upstreamSystemUnits includes these for systemd 259+
  systemd.suppressedSystemUnits = lib.mkForce [
    # Factory reset units (258+)
    "factory-reset.target"
    "factory-reset-now.target"
    "systemd-factory-reset-request.service"
    "systemd-factory-reset-reboot.service"
    "systemd-factory-reset.socket"
    "factory-reset.target.wants"

    # New sockets (258+)
    "systemd-journalctl.socket"
    "systemd-ask-password.socket"
    "systemd-logind-varlink.socket"
    "systemd-machined.socket"
    "systemd-mute-console.socket"
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
  # By overlaying buildPackages.systemd and systemdMinimal with systemd257,
  # all build-time systemd tools use the compatible 257.9 version.
  # Using the full systemd257 package is safe here — it just provides udevadm
  # and systemd-hwdb binaries at build time, so the extra runtime features
  # in the full package are irrelevant.
  nixpkgs.overlays = [
    (final: prev: {
      buildPackages = prev.buildPackages // {
        systemd = systemd257;
        systemdMinimal = systemd257;
      };
    })
  ];
}