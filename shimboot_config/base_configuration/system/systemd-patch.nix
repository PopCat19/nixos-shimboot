# systemd-patch.nix
#
# Purpose: Configure systemd to use patched 257.x from nixos-25.05 stable
#
# This module:
# - Sets systemd.package to systemd257 from specialArgs
# - Suppresses factory reset units (unconditional in unstable's module, not in 257)
# - Overrides buildPackages.systemd/systemdMinimal for ChromeOS kernel compatibility
#
# Systemd version constraint:
# - Ceiling: 257.x (258+ requires kernel >=5.10)
# - Reason: systemd 258+ uses open_tree()/move_mount() syscalls unavailable on
#   older shim kernels (octopus 4.14.x, dedede 5.4.x before certain commits)
# - Ref: https://github.com/ading2210/shimboot/issues/405
{
  systemd257,
  lib,
  ...
}:
{
  systemd.package = lib.mkForce systemd257;

  # Factory reset units are hardcoded in unstable's upstreamSystemUnits
  # but don't exist in systemd 257.x. Other units (journalctl, machined,
  # mute-console, etc.) are gated by passthru attrs which stable provides.
  systemd.suppressedSystemUnits = lib.mkForce [
    "factory-reset.target"
    "factory-reset-now.target"
    "systemd-factory-reset-request.service"
    "systemd-factory-reset-reboot.service"
    "factory-reset.target.wants"
  ];

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
