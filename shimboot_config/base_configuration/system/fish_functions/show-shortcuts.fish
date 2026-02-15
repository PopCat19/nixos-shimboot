#!/usr/bin/env fish

# Show Shortcuts Function
#
# Purpose: Display Hyprland keybindings with descriptions and categories
# Tags: # cat: CategoryName, # desc: Description Text
# Dependencies: string, math, column
#
# Usage:
#   show-shortcuts            - Show all
#   show-shortcuts <cat>      - Filter by category
#   show-shortcuts <search>   - Search descriptions/keys

function show-shortcuts
    set -l config_dir "$NIXOS_CONFIG_DIR"
    set -l keybinds_file "$config_dir/shimboot_config/main_configuration/home/hypr_config/hypr_modules/keybinds.nix"
    set -l userprefs_file "$config_dir/shimboot_config/main_configuration/home/hypr_config/userprefs.conf"

    set -l filter ""
    set -l search ""
    set -l list_only false
    set -l use_fzf false
    set -l search_term ""

    set -l i 1
    while test $i -le (count $argv)
        set -l arg "$argv[$i]"
        if test "$arg" = "--list" -o "$arg" = "-l"
            set list_only true
            set i (math $i + 1)
        else if test "$arg" = "--fzf" -o "$arg" = "-f"
            set use_fzf true
            set i (math $i + 1)
            if test $i -le (count $argv)
                set search_term "$argv[$i]"
                set i (math $i + 1)
            end
        else
            set search "$arg"
            set i (math $i + 1)
        end
    end

    # Handle --list option
    if test "$list_only" = true
        set -l categories (get_detected_categories "$keybinds_file" "$userprefs_file")
        set_color brgreen
        echo "Available shortcut categories:"
        set_color normal
        for cat in $categories
            echo "  • "(string trim "$cat")
        end
        echo ""
        set_color brblack; echo "Usage: show-shortcuts <category>"; set_color normal
        return
    end

    set -l all_shortcuts
    set -l current_cat "General"
    set -l current_desc ""

    # Parse config files using helper function
    set -a all_shortcuts (_parse_shortcuts_config "$keybinds_file")
    set -a all_shortcuts (_parse_shortcuts_config "$userprefs_file")

    if test (count $all_shortcuts) -eq 0
        set_color yellow; echo "No shortcuts with # desc: tags found."; set_color normal
        return
    end

    # Apply Filters
    set -l filtered
    for item in $all_shortcuts
        set -l parts (string split '|' "$item")
        if test -n "$search"
            string match -iqr "$search" "$parts[1] $parts[2]"; and set -a filtered "$item"
        else if test -n "$filter"
            test (string lower "$parts[3]") = "$filter"; and set -a filtered "$item"
        else
            set -a filtered "$item"
        end
    end

    # Render Header
    set -l box_width 62
    set -l title " HYPRLAND SHORTCUTS "
    test -n "$filter"; and set title " CATEGORY: "(string upper "$filter")" "
    test -n "$search"; and set title " SEARCH: $search "
    test "$use_fzf" = true; and set title " FUZZY SEARCH "

    set -l padding (math "($box_width - "(string length "$title")") / 2")
    set -l l_pad (math -s0 "floor($padding)")
    set -l r_pad (math -s0 "$box_width - "(string length "$title")" - $l_pad")

    set_color brgreen
    echo "╔"(string repeat -n $box_width "═")"╗"
    echo "║"(string repeat -n $l_pad " ")$title(string repeat -n $r_pad " ")"║"
    echo "╚"(string repeat -n $box_width "═")"╝"
    set_color normal; echo ""

    # Group by dynamically discovered categories
    set -l found_cats
    for i in $filtered; set -a found_cats (string split '|' "$i")[3]; end
    set found_cats (printf '%s\n' $found_cats | sort -u)

    for cat in $found_cats
        set_color brcyan; echo "[$cat]"; set_color normal
        echo "─────────────────────────────────────────────────────────────────────"
        for item in $filtered
            set -l p (string split '|' "$item")
            if test "$p[3]" = "$cat"
                echo -e "$p[1]\t$p[2]"
            end
        end | column -t -s (printf '\t')
        echo ""
    end

    # Check if fzf is available
    set -l fzf_available false
    if command -v fzf > /dev/null 2>&1
        set fzf_available true
    end

    # Handle fzf output
    if test "$use_fzf" = true
        if test "$fzf_available" = false
            set_color red; echo "Error: fzf is not installed. Please install fzf to use fuzzy search."; set_color normal
            echo ""
            echo " showing all shortcuts instead:"
            set -l prev_use_fzf "$use_fzf"
            set use_fzf false
        else
            set -l all_items
            for item in $filtered
                set -l p (string split '|' "$item")
                set -a all_items "$p[1] | $p[2] [$p[3]]"
            end

            set -l fzf_cmd "fzf --delimiter '|' --preview 'echo {+}' --preview-window=right:30%"
            if test -n "$search_term"
                set fzf_cmd "$fzf_cmd --query '$search_term'"
            end

            set -l selected (printf '%s\n' $all_items | eval $fzf_cmd)
            if test -n "$selected"
                set -l binding (string split '|' "$selected")[1]
                string trim "$binding"
            end
        end
    end

    set_color brblack; echo "Tip: # cat: <name> and # desc: <text> in config files"; set_color normal
end

function normalize_binding
    set -l out (string replace -a '$mainMod' 'SUPER' "$argv[1]")
    string replace -ra '[[:space:]]+' ' ' "$out" | string trim
end

function get_detected_categories
    for file in $argv
        test -f "$file"; and grep -oP '#\s*cat:\s*\K.+|#\s*=== \K.+?(?=\s*===)' "$file"
    end | string replace -r '.+?:' '' | sort -u
end

function _parse_shortcuts_config
    set -l file $argv[1]
    test -f "$file"; or return

    set -l current_cat "General"
    set -l current_desc ""

    while read -l line
        # Detect Section Header as Category (=== Name ===)
        if string match -qr '^\s*#\s*=== (.+) ===\s*$' "$line"
            set current_cat (string replace -r '^\s*#\s*=== (.+) ===\s*$' '$1' "$line")
        # Detect Category Tag (# cat: Name)
        else if string match -qr '^\s*#\s*cat:\s*(.+)' "$line"
            set current_cat (string replace -r '^\s*#\s*cat:\s*' '' "$line")

        # Detect Description Tag
        else if string match -qr '^\s*#\s*desc:\s*(.+)' "$line"
            set current_desc (string replace -r '^\s*#\s*desc:\s*' '' "$line")

        # Match Nix Binding ("mod, key, action")
        else if string match -qr '^\s*"([^"]+)"' "$line"; and test -n "$current_desc"
            set -l raw (string replace -r '^\s*"([^"]+)".*' '$1' "$line")
            set -l parts (string split ',' "$raw")
            if test (count $parts) -ge 2
                set -l binding (string trim "$parts[1]")", "(string trim "$parts[2]")
                echo (normalize_binding "$binding")"|"$current_desc"|"$current_cat
            end
            set current_desc ""

        # Match Conf Binding (bind = mod, key, action)
        else if string match -qr '^\s*bind[elmn]*\s*=' "$line"; and test -n "$current_desc"
            set -l binding (string replace -r '^\s*bind[elmn]*\s*=\s*([^,]+,\s*[^,]+),.*' '$1' "$line")
            echo (normalize_binding "$binding")"|"$current_desc"|"$current_cat
            set current_desc ""
        end
    end < "$file"
end
