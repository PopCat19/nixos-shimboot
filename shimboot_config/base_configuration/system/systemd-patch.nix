# systemd-patch.nix
#
# Purpose: Configure systemd to use pinned 257.9 with ChromeOS compatibility patch
#
# This module:
# - Sets systemd.package to systemd257 from specialArgs
# - Suppresses unit files missing from systemd 257.9 (added in 258+)
# - Overrides hwdb.bin generation to use systemd257's systemd-hwdb
#   (nixpkgs uses pkgs.buildPackages.systemd which defaults to the unstable
#   version, whose systemd-hwdb 260+ requires kernel >=5.10 open_tree() calls)
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

  # Override hwdb.bin generation to use systemd257's systemd-hwdb binary.
  #
  # nixpkgs hardcodes pkgs.buildPackages.systemd (currently 260.x) for the
  # systemd-hwdb builder, which fails on ChromeOS kernels <5.10 with:
  #   Failed to determine if '/build' points to the root directory: Protocol driver not attached
  #   Failed to enumerate hwdb files: Protocol driver not attached
  #
  # We rebuild hwdb.bin using the same logic but with systemd257's
  # systemd-hwdb, which doesn't require the open_tree()/move_mount() syscalls.
  environment.etc."udev/hwdb.bin".source = lib.mkForce
    let
      udev = config.systemd.package;
      cfg = config.services.udev;
    in
    pkgs.runCommand "hwdb.bin"
      {
        preferLocalBuild = true;
        allowSubstitutes = false;
        packages = lib.unique (map toString ([ udev ] ++ cfg.packages));
      }
      ''
        mkdir -p etc/udev/hwdb.d
        for i in $packages; do
          echo "Adding hwdb files for package $i"
          for j in $i/{etc,lib}/udev/hwdb.d/*; do
            cp $j etc/udev/hwdb.d/$(basename $j)
          done
        done

        echo "Generating hwdb database..."
        # Use the system's systemd (257.9) instead of pkgs.buildPackages.systemd (260.x)
        res="$(${lib.getBin systemd257}/bin/systemd-hwdb --root=$(pwd) update 2>&1)"
        echo "$res"
        [ -z "$(echo "$res" | egrep '^Error')" ]
        mv etc/udev/hwdb.bin $out
      '';
}