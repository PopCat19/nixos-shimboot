#!/usr/bin/env fish

# Fix Fish History Function
#
# Purpose: Repair corrupted Fish shell history file.
# Dependencies: fish, history command, tail, cp
# Related: fish.nix, list-fish-helpers.fish
#
# This function:
# - Creates backup of history file
# - Attempts repair via history merge
# - Falls back to truncation if merge fails
# - Preserves recent history entries

function fix-fish-history
    set_color blue; echo "[STEP] Fixing fish history corruption..."; set_color normal

    # Determine standard path
    set -l hist_path (set -q XDG_DATA_HOME; and echo "$XDG_DATA_HOME/fish/fish_history"; or echo "$HOME/.local/share/fish/fish_history")

    if not test -f "$hist_path"
        set_color yellow; echo "[WARN] History file not found at: $hist_path"; set_color normal
        return 1
    end

    # Backup
    cp "$hist_path" "$hist_path.bak"
    set_color green; echo "[INFO] Backup created at: $hist_path.bak"; set_color normal

    set_color blue; echo "[STEP] Attempting repair via merge..."; set_color normal
    if history merge
        set_color green; echo "[SUCCESS] History merged and repaired successfully."; set_color normal
    else
        set_color yellow; echo "[WARN] Merge failed. Attempting truncation repair..."; set_color normal
        # Fallback: keep recent 2800 lines (approx) to dump corrupt head
        tail -n 2800 "$hist_path" > "$hist_path.tmp"
        mv "$hist_path.tmp" "$hist_path"
        set_color green; echo "[SUCCESS] History file truncated (kept last 2800 lines)."; set_color normal
    end

    set_color cyan; echo "[INFO] Restart shell to see effects."; set_color normal
end
