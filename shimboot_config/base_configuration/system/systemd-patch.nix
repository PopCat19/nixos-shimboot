# systemd-patch.nix
#
# Purpose: Configure systemd to use patched 257.x from nixos-25.05 stable
#
# This module:
# - Sets systemd.package to systemd257 from specialArgs
# - Suppresses 258+ upstream units that don't exist in 257.x
# - Overrides buildPackages.systemd/systemdMinimal for ChromeOS kernel compatibility
#
# Systemd version constraint:
# - Ceiling: 257.x (258+ requires kernel >=5.10)
# - Reason: systemd 258+ uses open_tree()/move_mount() syscalls unavailable on
#   older shim kernels (octopus 4.14.x, dedede 5.4.x before certain commits)
# - Ref: https://github.com/ading2210/shimboot/issues/405
#
# Architecture (suppressedSystemUnits):
# - Uses unstable's systemd modules (no module swapping)
# - Sets systemd.package to patched 257.x from stable
# - Suppresses upstream units that 258+ modules reference but 257 lacks
# - No passthru hacks, no glibc mixing, no initrd rebuild issues
{
  systemd257,
  lib,
  config,
  ...
}:

let
  # Units that exist in systemd 258+ but not in 257.x
  # These are referenced by unstable's NixOS modules but don't exist in our package
  # Note: Some are conditional on package.withTpm2Units/etc, but 257's version
  # of these conditionals has fewer units than 258.
  missingUpstreamUnits = [
    # Added in systemd 258
    "systemd-journalctl.socket"
    "systemd-journalctl@.service"
    # TPM2: 258 adds tpm2-clear, but 257 only has pcrlock/setup
    "systemd-tpm2-clear.service"
    # Factory reset: all 258+, 257 has none
    "factory-reset.target"
    "systemd-factory-reset-request.service"
    "systemd-factory-reset-reboot.service"
  ];

  # Initrd units that exist in systemd 258+ but not in 257.x
  missingInitrdUnits = [
    # Breakpoint hooks added in systemd 258
    "breakpoint-pre-udev.service"
    "breakpoint-pre-basic.service"
    "breakpoint-pre-mount.service"
    "breakpoint-pre-switch-root.service"
    # Factory reset added in systemd 258
    "systemd-factory-reset-complete.service"
    "factory-reset-now.target"
  ];
in
{
  # Use patched systemd 257.x from nixos-25.05 stable
  systemd.package = lib.mkForce systemd257;

  # Suppress upstream system units that don't exist in 257.x
  systemd.suppressedSystemUnits = missingUpstreamUnits;

  # Suppress upstream initrd units that don't exist in 257.x
  boot.initrd.systemd.suppressedUnits = missingInitrdUnits;

  # Override buildPackages systemd to use 257.x.
  #
  # nixpkgs hardcodes pkgs.buildPackages.systemd for build-time operations:
  # 1. systemd-hwdb (hwdb.bin generation) — fails with "Protocol driver not attached"
  # 2. udevadm verify (udev rules validation) — fails with "Failed to chase..."
  #
  # Both fail on ChromeOS kernels <5.10 due to open_tree()/move_mount() syscalls.
  nixpkgs.overlays = [
    (_final: prev: {
      buildPackages = prev.buildPackages // {
        systemd = systemd257;
        systemdMinimal = systemd257;
      };
    })
  ];
}