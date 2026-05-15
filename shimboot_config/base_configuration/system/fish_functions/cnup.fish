# cnup.fish
#
# Purpose: Comprehensive NixOS configuration linting and formatting
#
# This module:
# - Runs statix to fix security issues and bad practices
# - Removes dead nix code with deadnix
# - Formats code with treefmt (RFC-style, from nixfmt-tree package)
# - Validates flake configuration (unless --no-flake or --no-check)
# - Automatically uses nix-shell if tools are not available
# - Always disables sandbox for shimboot compatibility

function cnup
    argparse no-flake no-check -- $argv
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

        # Sandbox is always disabled for shimboot to support old kernels in fleet
        set_color yellow
        echo "[INFO] Sandbox disabled (shimboot policy)"
        set_color normal
        set -l sandbox_args --option sandbox false
        set -l nixshell_sandbox_args --no-sandbox

        set -l check_cmd ''
        if not set -q _flag_no_flake; and not set -q _flag_no_check
            set check_cmd "&& nix flake check --impure --accept-flake-config $sandbox_args"
        end

        if test $use_nix_shell = true
            nix-shell $nixshell_sandbox_args -p statix deadnix nixfmt-tree --run "statix fix . && deadnix -e . && treefmt .$check_cmd"
        else
            eval "statix fix . && deadnix -e . && treefmt .$check_cmd"
        end
    end
end
