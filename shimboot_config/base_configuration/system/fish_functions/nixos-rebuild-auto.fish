# nixos-rebuild-auto.fish
#
# Purpose: Non-interactive NixOS rebuild for LLM automation
#
# This is a convenience wrapper for: nixos-rebuild-basic --auto --rollback [ARGS]
#
# Usage: nixos-rebuild-auto [OPTIONS] [COMMIT_MESSAGE]
#
# Options:
#   --rollback-on-fail    Rollback git commit if rebuild fails (default)
#   --no-rollback         Keep changes even if rebuild fails
#   --push-on-success     Push to remote after successful rebuild
#   --no-commit           Skip commit, just rebuild
#   --dry-run             Build without switching
#   --test                Test configuration without switching
#
# Exit codes:
#   0 - Success
#   1 - Build failed (and rollback failed or disabled)
#   2 - Commit failed
#   3 - Push failed

function nixos-rebuild-auto
    # Pass all args to nixos-rebuild-basic with --auto flag
    nixos-rebuild-basic --auto $argv
    return $status
end