# nixos-rebuild-auto.fish
#
# Purpose: Non-interactive NixOS rebuild for LLM automation
#
# This module:
# - Wraps nixos-rebuild-basic with --auto and --rollback flags
# - Supports push-on-success and dry-run options
# - Provides stable exit codes for automated workflows

function nixos-rebuild-auto
    # Pass all args to nixos-rebuild-basic with --auto flag
    nixos-rebuild-basic --auto $argv
    return $status
end