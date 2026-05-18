# Security Configuration Module
#
# Purpose: Configure system security and authorization
# Dependencies: polkit, rtkit, bubblewrap
# Related: services.nix, users.nix, packages.nix
#
# This module:
# - Enables PolicyKit for system authorization
# - Enables rtkit for realtime scheduling
# - Provides secure privilege escalation mechanisms
# - Creates SUID wrapper for bubblewrap to bypass ChromeOS kernel restrictions
{ pkgs, ... }:
let
  # LD_PRELOAD shim: intercepts mount("tmpfs", ...) → bind mount
  # Transparent to everything — Steam, Flatpak, bwrap, anything.
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

  # Convenience wrapper: bwrap-mount-shim steam
  # Sets LD_PRELOAD and execs the command.
  mountShimWrapper = pkgs.writeShellScriptBin "bwrap-mount-shim" ''
    export LD_PRELOAD="${mountShim}/lib/mount_shim.so''${LD_PRELOAD:+:}$LD_PRELOAD"
    exec "$@"
  '';
in
{
  security.polkit.enable = true;
  security.rtkit.enable = true;

  # Create a Set-UID wrapper for Bubblewrap
  # This allows bwrap to create namespaces even if the kernel
  # restricts unprivileged user namespaces (common in ChromeOS kernels).
  security.wrappers.bwrap = {
    owner = "root";
    group = "root";
    source = "${pkgs.bubblewrap}/bin/bwrap";
    setuid = true;
  };

  # Transparent wrapper: converts --tmpfs to --bind to bypass ChromeOS LSM.
  # Usage:
  #   bwrap-safe ./myapp              ← convenience: auto-adds sandbox defaults
  #   bwrap-safe --flags... -- cmd     ← explicit: full bwrap control
  #
  # Design follows the proxify pattern — explicit, self-contained, no side
  # effects beyond the invocation. Each --tmpfs gets a unique mktemp directory
  # that is cleaned up when bwrap exits.
  #
  # If the first argument is not a flag (does not start with --), standard
  # bwrap sandbox boilerplate is prepended: ro-bind /, /dev, /proc, tmpfs /tmp.
  security.wrappers.bwrap-safe = {
    owner = "root";
    group = "root";
    source = pkgs.writeShellScript "bwrap-safe" ''
      BWRAP_REAL="/run/wrappers/bin/bwrap"
      CACHE="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bwrap-cache"
      mkdir -p "$CACHE"

      # Convenience mode: if first arg is not a flag, prepend sandbox defaults
      if [ $# -gt 0 ] && [ "''${1#-}" = "$1" ]; then
        set -- --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp -- "$@"
      fi

      args=()
      dirs=""

      while [ $# -gt 0 ]; do
        case "$1" in
          --tmpfs)
            d=$(mktemp -d "$CACHE/tmpfs-XXXXXXXX")
            chmod 700 "$d"
            dirs="$dirs $d"
            args+=("--bind" "$d")
            shift 2
            ;;
          --tmpfs=*)
            d=$(mktemp -d "$CACHE/tmpfs-XXXXXXXX")
            chmod 700 "$d"
            dirs="$dirs $d"
            args+=("--bind" "$d")
            shift
            ;;
          *)
            args+=("$1")
            shift
            ;;
        esac
      done

      trap 'for d in $dirs; do rm -rf "$d" 2>/dev/null; done' EXIT
      exec "$BWRAP_REAL" "''${args[@]}"
    '';
  };

  # Ensure wrappers are in the system path
  # bwrap-safe: SUID bwrap for namespaces + argument-rewriting wrapper
  # bwrap-mount-shim: LD_PRELOAD shim for transparent Steam/Flatpak support
  environment.systemPackages = [
    pkgs.bubblewrap
    mountShim
    mountShimWrapper
  ];
}
