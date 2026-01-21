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
    set_color blue; echo "[FISH] Fish Helpers & Shortcuts"; set_color normal
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    set_color green; echo "[INFO] Helper Functions:"; set_color normal

    # Dynamically discover helper functions
    set -l helper_patterns "show-shortcuts" "expand_rootfs" "fix-steam-bwrap" "setup_nixos" "setup_nixos_config" "nixos-" "setup_" "shimboot_" "fix" "list" "harvest"
    set -l found_helpers

    for pattern in $helper_patterns
        set -l matches (functions | grep "$pattern" | sort)
        if test -n "$matches"
            for match in $matches
                if not contains "$match" $found_helpers
                    set found_helpers $found_helpers "$match"
                    echo "   • $match"
                end
            end
        end
    end

    # If no pattern matches found, show all non-builtin functions
    if test -z "$found_helpers"
        functions | grep -vE "^_|fish_|^__" | sort | awk '{print "   • " $0}'
    end

    echo ""
    set_color green; echo "[INFO] Abbreviations:"; set_color normal
    abbr --list | sort | awk '{print "   • " $0}'

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    set_color cyan; echo "[INFO] Tips:"; set_color normal
    echo "   Type 'type <name>' to see definition"
    echo "   Type 'fixhist' to repair corrupt history"

    # Show any functions that might be broken or need attention
    set -l potential_issues
    for func in (functions | grep -E "fix|setup|nixos" | head -5)
        if not functions -q "$func"
            set potential_issues $potential_issues "$func"
        end
    end

    if test -n "$potential_issues"
        echo ""
        set_color yellow; echo "[WARN] Check these functions:"; set_color normal
        for issue in $potential_issues
            echo "   • $issue (may need definition)"
        end
    end
end
