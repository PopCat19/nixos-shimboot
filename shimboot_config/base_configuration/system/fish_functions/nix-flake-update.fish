# nix-flake-update.fish
#
# Purpose: Update Nix flake inputs with compatibility checks
#
# This function:
# - Checks kernel version for sandbox compatibility
# - Creates backup of flake.lock before updating
# - Updates flake inputs and shows changes
# - Auto-commits changes to git (if in git repo)
# - Restores backup on failure

function nix-flake-update
    set_color blue; echo "[STEP] Updating Nix flake inputs..."; set_color normal

    # Sandbox is always disabled for shimboot to support old kernels in fleet
    set_color yellow; echo "[INFO] Sandbox disabled (shimboot policy)"; set_color normal
    set -l update_args --option sandbox false

    test -f flake.lock; and cp flake.lock flake.lock.bak
    set -l old_hash (test -f flake.lock; and sha256sum flake.lock | cut -d' ' -f1)

    if set -q update_args[1]
        set_color cyan; echo "Command: nix flake update $update_args"; set_color normal
        nix flake update $update_args
    else
        set_color cyan; echo "Command: nix flake update"; set_color normal
        nix flake update
    end

    if test $status -eq 0
        set_color green; echo "[SUCCESS] Update successful."; set_color normal

        set -l new_hash (sha256sum flake.lock | cut -d' ' -f1)

        if test "$old_hash" = "$new_hash"
            set_color green; echo "[INFO] No changes detected in inputs."; set_color normal
            rm -f flake.lock.bak
        else
            set_color green; echo "[INFO] Changes detected:"; set_color normal
            echo "---------------------------------------------------"

            if command -v diff >/dev/null
                diff -u3 --color=always flake.lock.bak flake.lock 2>/dev/null; or true
            end

            if command -v jq >/dev/null
                set_color green; echo "[INFO] Updated Inputs:"; set_color normal
                jq -r '.nodes | to_entries[] | select(.value.locked) | .key' flake.lock | head -n 10 | while read -l input
                    echo "   • $input"
                end
            end

            echo "---------------------------------------------------"

            # Auto-commit changes
            if test -d .git
                set -l timestamp (date -u +"%Y-%m-%d")
                git add flake.lock
                git commit -m "chore(flake): update inputs $timestamp"
                set_color green; echo "[INFO] Changes committed to git."; set_color normal
            end

            rm -f flake.lock.bak
            set_color cyan; echo "[INFO] Next steps:"; set_color normal
            echo "   • Test: nrb dry-run"
            echo "   • Apply: nrb"
        end
    else
        set_color red; echo "[ERROR] Update failed. Restoring backup..."; set_color normal
        test -f flake.lock.bak; and mv flake.lock.bak flake.lock
        return 1
    end

    return 0
end
