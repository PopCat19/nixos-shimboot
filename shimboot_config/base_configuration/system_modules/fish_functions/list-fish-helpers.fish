function list-fish-helpers
    echo "🐟 Available Fish Functions:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    functions | grep -v "^_" | grep -v "^fish_" | sort
    echo ""
    echo "🔤 Available Fish Abbreviations:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    abbr --list | sort
    echo ""
    echo "💡 Use 'type <function_name>' to see function definition"
    echo "💡 Use 'abbr --show <abbr_name>' to see abbreviation expansion"
    echo ""
    echo "🔧 Quick Fix for corrupted fish history: fixhist"
end