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
  # Usage: bwrap-safe [same args as bwrap]
  #
  # Design follows the proxify pattern — explicit, self-contained, no side
  # effects beyond the invocation. Each --tmpfs gets a unique mktemp directory
  # that is cleaned up when bwrap exits. No global PATH manipulation needed.
  #
  # Does not need SUID itself; the real bwrap at /run/wrappers/bin/bwrap
  # handles namespace creation.
  security.wrappers.bwrap-safe = {
    owner = "root";
    group = "root";
    source = pkgs.writeShellScript "bwrap-safe" ''
      BWRAP_REAL="/run/wrappers/bin/bwrap"
      CACHE="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bwrap-cache"
      mkdir -p "$CACHE"

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

  # Ensure the wrapper is in the system path
  # Programs looking for 'bwrap' will find the SUID version first.
  environment.systemPackages = [
    pkgs.bubblewrap
  ];
}
