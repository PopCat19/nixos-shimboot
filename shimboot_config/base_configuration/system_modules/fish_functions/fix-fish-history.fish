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
    echo "🔧 Fixing fish history corruption..."

    # Determine standard path
    set -l hist_path (set -q XDG_DATA_HOME; and echo "$XDG_DATA_HOME/fish/fish_history"; or echo "$HOME/.local/share/fish/fish_history")

    if not test -f "$hist_path"
        echo "⚠️  History file not found at: $hist_path"
        return 1
    end

    # Backup
    cp "$hist_path" "$hist_path.bak"
    echo "💾 Backup created at: $hist_path.bak"

    echo "🔄 Attempting repair via merge..."
    if history merge
        echo "✅ History merged and repaired successfully."
    else
        echo "⚠️  Merge failed. Attempting truncation repair..."
        # Fallback: keep recent 2800 lines (approx) to dump corrupt head
        tail -n 2800 "$hist_path" > "$hist_path.tmp"
        mv "$hist_path.tmp" "$hist_path"
        echo "✅ History file truncated (kept last 2800 lines)."
    end

    echo "💡 Restart shell to see effects."
end