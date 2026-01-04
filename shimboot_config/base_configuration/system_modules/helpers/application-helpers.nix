# Application Helpers Module
#
# Purpose: Provide application-specific utility scripts
# Dependencies: bubblewrap
# Related: helpers.nix, security.nix
#
# This module:
# - Fixes Steam's internal bwrap with SUID wrapper
# - Patches security permissions for Steam runtime
# - Maintains system security while enabling Steam functionality
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # Script to overwrite Steam's internal bwrap with our SUID system wrapper
    (writeShellScriptBin "fix-steam-bwrap" ''
      set -euo pipefail

      # Colors & Logging
      BOLD="\033[1m"
      GREEN="\033[1;32m"
      YELLOW="\033[1;33m"
      RED="\033[1;31m"
      BLUE="\033[1;34m"
      CYAN="\033[1;36m"
      NC="\033[0m"

      echo -e "''${BLUE}[INFO]''${NC} Searching for Steam directories..."
      HOME_DIR="$HOME"

      if [ ! -d "$HOME_DIR/.steam" ]; then
        echo -e "''${RED}[ERROR]''${NC} Steam directory not found at $HOME_DIR/.steam"
        exit 1
      fi

      echo -e "''${BLUE}[INFO]''${NC} Locating srt-bwrap instances..."
      # Find all instances of Steam's internal bwrap
      steam_bwraps=$(find "$HOME_DIR/.steam" -name "srt-bwrap" 2>/dev/null)

      if [ -z "$steam_bwraps" ]; then
        echo -e "''${YELLOW}[WARN]''${NC} No srt-bwrap binaries found. You may need to launch Steam once first."
        exit 0
      fi

      # The SUID wrapper created by security.wrappers
      SYSTEM_BWRAP="/run/wrappers/bin/bwrap"

      if [ ! -f "$SYSTEM_BWRAP" ]; then
        echo -e "''${RED}[ERROR]''${NC} SUID bwrap not found at $SYSTEM_BWRAP"
        echo -e "''${CYAN}[INFO]''${NC} Ensure security.wrappers.bwrap is configured in configuration.nix"
        exit 1
      fi

      for target in $steam_bwraps; do
        echo -e "''${BLUE}[STEP]''${NC} Patching: $target"
        # Remove the existing binary/symlink
        rm -f "$target"
        # Symlink to our SUID wrapper
        ln -s "$SYSTEM_BWRAP" "$target"
      done

      echo -e "''${GREEN}[SUCCESS]''${NC} Steam bwrap patched successfully."
    '')
  ];
}
