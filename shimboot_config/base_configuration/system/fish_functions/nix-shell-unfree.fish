# nix-shell-unfree.fish
#
# Purpose: Enable Nix shell with unfree and insecure packages
#
# This module:
# - Sets environment variables for unfree/insecure packages
# - Runs nix-shell with packages if provided
# - Shows informational message when used interactively

function nix-shell-unfree
    set -lx NIXPKGS_ALLOW_UNFREE 1
    set -lx NIXPKGS_ALLOW_INSECURE 1
    if test (count $argv) -gt 0
        nix-shell $argv
    else
        echo "NIXPKGS_ALLOW_UNFREE and NIXPKGS_ALLOW_INSECURE are now set for this session."
        echo "You can now run nix-shell with packages that require these flags."
    end
end
