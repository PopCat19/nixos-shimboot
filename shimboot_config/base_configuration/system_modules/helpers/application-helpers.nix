# Application Helpers Module
#
# Purpose: Provide application-specific utility scripts
# Dependencies: bubblewrap
# Related: helpers.nix, security.nix
#
# This module provides:
# - fix-steam-bwrap: Patch Steam's internal bwrap with SUID wrapper
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # Script to overwrite Steam's internal bwrap with our SUID system wrapper
    (writeShellScriptBin "fix-steam-bwrap" ''
      echo "Searching for Steam directories..."
      HOME_DIR="$HOME"

      if [ ! -d "$HOME_DIR/.steam" ]; then
        echo "Steam directory not found at $HOME_DIR/.steam"
        exit 1
      fi

      echo "Locating srt-bwrap instances..."
      # Find all instances of Steam's internal bwrap
      steam_bwraps=$(find "$HOME_DIR/.steam" -name "srt-bwrap" 2>/dev/null)

      if [ -z "$steam_bwraps" ]; then
        echo "No srt-bwrap binaries found. You may need to launch Steam once first."
        exit 0
      fi

      # The SUID wrapper created by security.wrappers
      SYSTEM_BWRAP="/run/wrappers/bin/bwrap"

      if [ ! -f "$SYSTEM_BWRAP" ]; then
        echo "Error: SUID bwrap not found at $SYSTEM_BWRAP"
        echo "Ensure security.wrappers.bwrap is configured in configuration.nix"
        exit 1
      fi

      for target in $steam_bwraps; do
        echo "Patching: $target"
        # Remove the existing binary/symlink
        rm -f "$target"
        # Symlink to our SUID wrapper
        ln -s "$SYSTEM_BWRAP" "$target"
      done

      echo "Steam bwrap patched successfully."
    '')
  ];
}
