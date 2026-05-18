# Security Configuration Module
#
# Purpose: Configure system security and authorization
# Dependencies: polkit, rtkit, bubblewrap
# Related: services.nix, users.nix, packages.nix
#
# This module:
# - Enables PolicyKit for system authorization
# - Enables rtkit for realtime scheduling
# - Creates SUID bwrap for namespace creation (ChromeOS kernel restriction)
# - Builds LD_PRELOAD mount shim to bypass chromiumos LSM tmpfs block
{ pkgs, ... }:
let
  # LD_PRELOAD shim: intercepts mount("tmpfs", ...) → bind mount.
  # Transparent to everything — Steam, Flatpak, bwrap, Nix packages.
  mountShim = pkgs.stdenv.mkDerivation {
    name = "bwrap-mount-shim";
    src = ../../patches/bwrap-mount-shim.c;
    dontUnpack = true;
    buildPhase = ''
      $CC -shared -fPIC -o mount_shim.so "$src" -ldl
    '';
    installPhase = ''
      mkdir -p "$out/lib"
      cp mount_shim.so "$out/lib/mount_shim.so"
    '';
    meta.license = pkgs.lib.licenses.gpl3;
  };

  # Single entry point. Usage:
  #   bwrap-mount-shim steam              ← LD_PRELOAD only (Steam runs its own bwrap)
  #   bwrap-mount-shim ./myapp            ← auto-wraps in bwrap with sandbox defaults
  #   bwrap-mount-shim --flags... -- cmd  ← explicit bwrap control
  mountShimBin = pkgs.writeShellScriptBin "bwrap-mount-shim" ''
    export LD_PRELOAD="${mountShim}/lib/mount_shim.so''${LD_PRELOAD:+:}$LD_PRELOAD"

    # Convenience: if first arg is not a bwrap flag, auto-wrap in sandbox
    if [ $# -gt 0 ] && [ "''${1#-}" = "$1" ]; then
      exec /run/wrappers/bin/bwrap \
        --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp -- "$@"
    fi

    exec "$@"
  '';
in
{
  security.polkit.enable = true;
  security.rtkit.enable = true;

  # SUID bwrap — required for namespace creation on ChromeOS kernels
  # that restrict unprivileged user namespaces.
  security.wrappers.bwrap = {
    owner = "root";
    group = "root";
    source = "${pkgs.bubblewrap}/bin/bwrap";
    setuid = true;
  };

  environment.systemPackages = [
    pkgs.bubblewrap
    mountShim
    mountShimBin
  ];
}
