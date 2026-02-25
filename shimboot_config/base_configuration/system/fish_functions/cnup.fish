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
# - Validates flake configuration (unless --no-flake or --no-check)
# - Automatically uses nix-shell if tools are not available
# - Detects kernel version and disables sandbox for older kernels

function cnup
    argparse 'no-flake' 'no-check' -- $argv
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

        set -l sandbox_args
        set -l nixshell_sandbox_args
        set -l kver (uname -r)
        if string match -qr '^([0-4]\.|5\.[0-5][^0-9])' "$kver"
            set_color yellow; echo "[WARN] Kernel $kver (< 5.6) detected. Disabling sandbox."; set_color normal
            set sandbox_args --option sandbox false
            set nixshell_sandbox_args --no-sandbox
        else
            set_color green; echo "[INFO] Kernel $kver detected. Using default sandbox."; set_color normal
        end

        set -l check_cmd ''
        if not set -q _flag_no_flake; and not set -q _flag_no_check
            set check_cmd "&& nix flake check --impure --accept-flake-config --verbose $sandbox_args"
        end

        if test $use_nix_shell = true
            nix-shell $nixshell_sandbox_args -p statix deadnix nixfmt-tree --run "statix fix . && deadnix -e . && treefmt .$check_cmd"
        else
            eval "statix fix . && deadnix -e . && treefmt .$check_cmd"
        end
    end
end
