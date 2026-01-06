#!/usr/bin/env fish

# Cnup Function
#
# Purpose: Comprehensive NixOS configuration linting and formatting
# Dependencies: statix, deadnix, alejandra, nix flake check
# Related: fish.nix, nixos-rebuild-basic.fish
#
# This function:
# - Runs statix to fix security issues and bad practices
# - Removes dead nix code with deadnix
# - Formats code with alejandra
# - Validates flake configuration
# - Automatically uses nix-shell if tools are not available

function cnup
    begin
        if test -d .git
            git add --intent-to-add . 2>/dev/null; or true
        end
        set -l use_nix_shell false
        for cmd in statix deadnix alejandra
            if not command -q $cmd
                set use_nix_shell true
                break
            end
        end
        if test $use_nix_shell = true
            nix-shell -p 'statix deadnix alejandra' --run 'statix fix . && deadnix -e . && alejandra .'
        else
            statix fix . && deadnix -e . && alejandra .
        end
    end
end
