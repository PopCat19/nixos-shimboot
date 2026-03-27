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

  # Create a wrapper script that works around ChromeOS LSM restrictions
  # The chromiumos LSM blocks tmpfs mounts, so tmpfs converted to bind mounts
  security.wrappers.bwrap-safe = {
    owner = "root";
    group = "root";
    source = pkgs.writeShellScript "bwrap-safe" ''
      # Wrapper that converts tmpfs mounts to bind mounts
      # to work around ChromeOS LSM restrictions
      BWRAP_REAL="/run/wrappers/bin/bwrap"
      BWRAP_CACHE_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bwrap-cache"
      mkdir -p "$BWRAP_CACHE_DIR"

      args=()
      skip_next=false
      tmpfs_count=0

      for arg in "$@"; do
        if [[ "$skip_next" == "true" ]]; then
          skip_next=false
          continue
        fi

        if [[ "$arg" == "--tmpfs" ]]; then
          tmpfs_dir="''${BWRAP_CACHE_DIR}/tmpfs-''${tmpfs_count}"
          mkdir -p "$tmpfs_dir"
          chmod 700 "$tmpfs_dir"
          args+=("--bind" "$tmpfs_dir")
          tmpfs_count=$((tmpfs_count + 1))
          skip_next=true
          continue
        fi

        args+=("$arg")
      done

      exec "$BWRAP_REAL" "''${args[@]}"
    '';
    setuid = true;
  };

  # Ensure the wrapper is in the system path
  # Programs looking for 'bwrap' will find the SUID version first.
  environment.systemPackages = [
    pkgs.bubblewrap
  ];
}
