#!/usr/bin/env fish

# List Fish Helpers Function
#
# Purpose: Display all available Fish functions and abbreviations.
# Dependencies: fish, functions, abbr, awk, grep
# Related: fish.nix, fish-greeting.fish
#
# This function:
# - Lists all custom Fish functions
# - Shows all Fish abbreviations
# - Provides usage tips for discovery
# - Formats output for readability

function list-fish-helpers
    echo "🐟 Fish Helpers & Shortcuts"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    echo "🔧 Functions:"
    functions | grep -vE "^_|fish_" | sort | awk '{print "   • " $0}'
    
    echo ""
    echo "🔤 Abbreviations:"
    abbr --list | sort | awk '{print "   • " $0}'
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "💡 Tips:"
    echo "   Type 'type <name>' to see definition"
    echo "   Type 'fixhist' to repair corrupt history"
end