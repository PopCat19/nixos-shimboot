# bwrap Fix Module
#
# Purpose: Enable bwrap on ChromeOS kernel 5.4 by setting setuid bit
# Dependencies: bubblewrap
# Related: hardware.nix, permissions-helpers.nix
#
# This module:
# - Wraps bubblewrap with setuid permissions
# - Provides activation script to fix Steam's bwrap copies
# - Works around kernel namespace limitations on signed shim kernels
{
  config,
  pkgs,
  lib,
  userConfig,
  ...
}: {
  # Wrap bwrap with setuid bit
  security.wrappers.bwrap = {
    owner = "root";
    group = "root";
    source = "${pkgs.bubblewrap}/bin/bwrap";
    setuid = true;
  };

  # Ensure bubblewrap is installed
  environment.systemPackages = with pkgs; [
    bubblewrap
  ];

  # Activation script to fix Steam's bwrap copies
  system.activationScripts.fix-steam-bwrap = {
    text = ''
      echo "Checking for Steam bwrap copies..."

      # Get actual user's home (not root's)
      USER_HOME="/home/${userConfig.user.username}"

      if [ -d "$USER_HOME/.steam" ]; then
        echo "Fixing Steam bwrap copies for ${userConfig.user.username}..."

        # Find and fix all srt-bwrap binaries
        find "$USER_HOME/.steam" -name 'srt-bwrap' -type f 2>/dev/null | while read -r bwrap; do
          if [ -f "$bwrap" ]; then
            # Copy our setuid wrapper
            cp /run/wrappers/bin/bwrap "$bwrap" 2>/dev/null || true
            chmod u+s "$bwrap" 2>/dev/null || true
            echo "  ✓ Fixed: $bwrap"
          fi
        done
      else
        echo "  Steam not installed yet, skipping..."
      fi
    '';
    deps = []; # Run early in boot
  };
}
