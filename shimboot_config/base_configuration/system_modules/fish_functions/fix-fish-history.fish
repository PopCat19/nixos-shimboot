# Fix Fish History Function
#
# Purpose: Repair corrupted Fish shell history files
# Dependencies: head, cp, mv
# Related: fish-functions.nix, fish.nix
#
# This function:
# - Creates backup of corrupted history file
# - Attempts automatic repair using history merge
# - Falls back to manual truncation if needed

function fix-fish-history
    echo "🔧 Fixing fish history corruption..."

    set -l history_file (set -q XDG_DATA_HOME; and echo "$XDG_DATA_HOME/fish/fish_history"; or echo "$HOME/.local/share/fish/fish_history")

    if not test -f "$history_file"
        echo "⚠️  History file not found at: $history_file"
        return 1
    end

    set -l backup_file "$history_file.bak"
    cp "$history_file" "$backup_file"
    echo "💾 Created backup at: $backup_file"

    echo "🔄 Attempting to repair history file..."

    history merge

    if test $status -ne 0
        echo "⚠️  Standard repair failed, attempting manual fix..."

        set -l offset 2800

        head -n $offset "$history_file" > "$history_file.tmp"
        mv "$history_file.tmp" "$history_file"

        echo "✅ History file truncated before corruption point"
    else
        echo "✅ History file repaired successfully"
    end

    echo "💡 You may need to restart fish for changes to take effect"
end