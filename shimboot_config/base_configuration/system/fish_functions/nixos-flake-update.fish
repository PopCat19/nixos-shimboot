#!/usr/bin/env fish

# NixOS Flake Update Function
#
# Purpose: Update NixOS flake inputs with compatibility checks.
# Dependencies: nix, jq, diff, sha256sum
# Related: nixos-rebuild-basic.fish, fish.nix
#
# This function:
# - Checks kernel version for sandbox compatibility
# - Creates backup of flake.lock
# - Updates flake inputs
# - Shows changes and provides next steps
# - Restores backup on failure

function nixos-flake-update
    set -l original_dir (pwd)
    cd "$NIXOS_CONFIG_DIR"

    set_color blue; echo "[STEP] Updating NixOS flake inputs..."; set_color normal
    
    # Kernel Sandbox Check
    set -l update_args ""
    if string match -qr '^([0-4]\.|5\.[0-5][^0-9])' (uname -r)
    set_color yellow; echo "[WARN] Legacy kernel detected. Disabling sandbox."; set_color normal
    set update_args "--option" "sandbox" "false"
    end

    # Backup & Prep
    test -f flake.lock; and cp flake.lock flake.lock.bak
    set -l old_hash (test -f flake.lock; and sha256sum flake.lock | cut -d' ' -f1)

    set_color cyan; echo "Command: nix flake update $update_args"; set_color normal
    
    if nix flake update $update_args
    set_color green; echo "[SUCCESS] Update successful."; set_color normal
    
    set -l new_hash (sha256sum flake.lock | cut -d' ' -f1)
    
    if test "$old_hash" = "$new_hash"
    set_color green; echo "[INFO] No changes detected in inputs."; set_color normal
    rm -f flake.lock.bak
    else
    set_color green; echo "[INFO] Changes detected:"; set_color normal
    echo "---------------------------------------------------"
    
    # Show Diff
    if command -v diff >/dev/null
    diff -u3 --color=always flake.lock.bak flake.lock 2>/dev/null; or true
    end
    
    # Summarize Changes via JQ
    if command -v jq >/dev/null
    set_color green; echo "[INFO] Updated Inputs:"; set_color normal
    jq -r '.nodes | to_entries[] | select(.value.locked) | .key' flake.lock | head -n 10 | sed 's/^/   • /'
    end

    echo "---------------------------------------------------"
    set_color cyan; echo "[INFO] Next steps:"; set_color normal
    echo "   • Test: nrb dry-run"
    echo "   • Apply: nrb switch"
    echo "   • Revert: mv flake.lock.bak flake.lock"
    end
    else
    set_color red; echo "[ERROR] Update failed. Restoring backup..."; set_color normal
    test -f flake.lock.bak; and mv flake.lock.bak flake.lock
    cd "$original_dir"
    return 1
    end

    cd "$original_dir"
end
