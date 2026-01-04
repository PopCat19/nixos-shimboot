#!/usr/bin/env fish

# Fix Steam Bwrap Function
#
# Purpose: Patch Steam's internal bwrap with SUID wrapper
# Dependencies: find, rm, ln
# Related: application-helpers.nix, security.nix
#
# This function:
# - Fixes Steam's internal bwrap with SUID wrapper
# - Patches security permissions for Steam runtime
# - Maintains system security while enabling Steam functionality

function fix-steam-bwrap
    set -euo pipefail

    # Colors & Logging
    set -l BOLD "\033[1m"
    set -l GREEN "\033[1;32m"
    set -l YELLOW "\033[1;33m"
    set -l RED "\033[1;31m"
    set -l BLUE "\033[1;34m"
    set -l CYAN "\033[1;36m"
    set -l NC "\033[0m"

    echo -e "$BLUE[INFO]$NC Searching for Steam directories..."
    set -l HOME_DIR "$HOME"

    if not test -d "$HOME_DIR/.steam"
        echo -e "$RED[ERROR]$NC Steam directory not found at $HOME_DIR/.steam"
        exit 1
    end

    echo -e "$BLUE[INFO]$NC Locating srt-bwrap instances..."
    # Find all instances of Steam's internal bwrap
    set -l steam_bwraps (find "$HOME_DIR/.steam" -name "srt-bwrap" 2>/dev/null)

    if test -z "$steam_bwraps"
        echo -e "$YELLOW[WARN]$NC No srt-bwrap binaries found. You may need to launch Steam once first."
        exit 0
    end

    # The SUID wrapper created by security.wrappers
    set -l SYSTEM_BWRAP "/run/wrappers/bin/bwrap"

    if not test -f "$SYSTEM_BWRAP"
        echo -e "$RED[ERROR]$NC SUID bwrap not found at $SYSTEM_BWRAP"
        echo -e "$CYAN[INFO]$NC Ensure security.wrappers.bwrap is configured in configuration.nix"
        exit 1
    end

    for target in $steam_bwraps
        echo -e "$BLUE[STEP]$NC Patching: $target"
        # Remove the existing binary/symlink
        rm -f "$target"
        # Symlink to our SUID wrapper
        ln -s "$SYSTEM_BWRAP" "$target"
    end

    echo -e "$GREEN[SUCCESS]$NC Steam bwrap patched successfully."
end
