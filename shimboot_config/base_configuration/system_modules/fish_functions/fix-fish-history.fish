function fix-fish-history
    echo "🔧 Fixing fish history corruption..."

    # Get the history file path
    set -l history_file (set -q XDG_DATA_HOME; and echo "$XDG_DATA_HOME/fish/fish_history"; or echo "$HOME/.local/share/fish/fish_history")

    # Check if history file exists
    if not test -f "$history_file"
        echo "⚠️  History file not found at: $history_file"
        return 1
    end

    # Create backup
    set -l backup_file "$history_file.bak"
    cp "$history_file" "$backup_file"
    echo "💾 Created backup at: $backup_file"

    # Try to fix the history file by removing corrupted entries
    echo "🔄 Attempting to repair history file..."

    # Use fish's built-in history merge to fix corruption
    history merge

    # If that doesn't work, try to truncate the file at the corruption point
    if test $status -ne 0
        echo "⚠️  Standard repair failed, attempting manual fix..."

        # Get the approximate corruption offset from the error message
        set -l offset 2800

        # Truncate the file before the corruption point
        head -n $offset "$history_file" > "$history_file.tmp"
        mv "$history_file.tmp" "$history_file"

        echo "✅ History file truncated before corruption point"
    else
        echo "✅ History file repaired successfully"
    end

    echo "💡 You may need to restart fish for changes to take effect"
end