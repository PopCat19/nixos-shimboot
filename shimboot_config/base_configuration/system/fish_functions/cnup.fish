#!/usr/bin/env fish

# Cnup Function
#
# Purpose: Comprehensive NixOS configuration linting and formatting
# Dependencies: statix, deadnix, treefmt (from nixfmt-tree), nix flake check
# Related: fish.nix, nixos-rebuild-basic.fish
#
# This function:
# - Runs statix to fix security issues and bad practices
# - Removes dead nix code with deadnix
# - Formats code with treefmt (RFC-style, from nixfmt-tree package)
# - Validates flake configuration (unless --no-check)
# - Automatically uses nix-shell if tools are not available

function cnup
    argparse 'no-check' -- $argv
    begin
        if test -d .git
            git add --intent-to-add . 2>/dev/null; or true
        end
        set -l use_nix_shell false
        for cmd in statix deadnix treefmt
            if not command -q $cmd
                set use_nix_shell true
                break
            end
        end
        set -l check_cmd '&& nix flake check --impure --accept-flake-config --verbose'
        if set -q _flag_no_check
            set check_cmd ''
        end
        if test $use_nix_shell = true
            nix-shell -p statix deadnix nixfmt-tree --run "statix fix . && deadnix -e . && treefmt .$check_cmd"
        else
            eval "statix fix . && deadnix -e . && treefmt .$check_cmd"
        end
    end
end
