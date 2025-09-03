#!/usr/bin/env fish

# Screenshot wrapper using hyprshot with hyprshade integration
# Usage: screenshot [monitor|region|window]
#
# Behavior:
# - Uses hyprshot with --freeze for clean capture
# - Always saves to XDG_SCREENSHOTS_DIR (defaults to ~/Pictures/Screenshots)
# - Copies PNG to clipboard when wl-copy/xclip are available
# - Filename: appname_yyyymmdd-N.png (N increments per day/app)
# - Temporarily disables hyprshade during capture (restores after)

function _slugify_app_name --description 'Normalize string to filesystem-safe slug'
    set -l s $argv
    if test -z "$s"
        echo "screen"
        return
    end
    set -l out (string lower -- $s)
    set out (string replace -ra '[^a-z0-9._-]' '-' -- $out)
    set out (string replace -ra '-+' '-' -- $out)
    set out (string trim -c '-' -- $out)
    if test -z "$out"
        echo "screen"
    else
        echo $out
    end
end

function get_app_name --description 'Detect active window class via hyprctl'
    set -l app "screen"
    if type -q hyprctl
        set -l json (hyprctl activewindow -j 2>/dev/null)
        if test -n "$json"
            set -l cls (echo $json | jq -r '.class // empty' 2>/dev/null)
            if test -n "$cls"
                set app $cls
            end
        end
    end
    _slugify_app_name $app
end

function next_filename --description 'Generate next incremental filename'
    # args: <dir> <app>
    set -l dir $argv[1]
    set -l app $argv[2]
    set -l date (date +%Y%m%d)
    set -l prefix (printf "%s_%s-" $app $date)
    set -l n 1
    while test -e "$dir/$prefix$n.png"
        set n (math $n + 1)
    end
    echo "$prefix$n.png"
end

function run_with_hyprshade_workaround --description 'Temporarily disable hyprshade while running a command'
    if type -q hyprshade
        set -l shader (hyprshade current 2>/dev/null; or echo "")
        if test -n "$shader" -a "$shader" != "Off"
            hyprshade off >/dev/null 2>&1
            $argv
            hyprshade on $shader >/dev/null 2>&1; or true
            return
        end
    end
    $argv
end

function copy_to_clipboard --description 'Copy PNG to clipboard if tools available'
    set -l path $argv[1]
    if test -z "$path" -o not -f "$path"
        return 1
    end
    if type -q wl-copy
        wl-copy --type image/png < "$path"
        return
    else if type -q xclip
        xclip -selection clipboard -t image/png -i "$path"
        return
    end
    # No clipboard utility available; skip silently
end

function take_screenshot --description 'Perform capture using hyprshot'
    # args: <hyprshot-mode> <dir> <filename>
    set -l mode $argv[1]
    set -l dir $argv[2]
    set -l filename $argv[3]
    set -l screenshot_path "$dir/$filename"

    if not type -q hyprshot
        echo "hyprshot not found in PATH"
        return 127
    end

    if run_with_hyprshade_workaround hyprshot --freeze --silent -m $mode -o "$dir" -f "$filename"
        if test -f "$screenshot_path"
            copy_to_clipboard "$screenshot_path"; or true
            notify-send "Screenshot" "$mode screenshot saved: $filename" -i camera-photo; or true
            echo "Saved: $screenshot_path"
        else
            echo "Screenshot cancelled - no file created"
        end
    else
        if test -f "$screenshot_path"
            rm -f "$screenshot_path"
            echo "Screenshot cancelled - cleaned up partial file"
        else
            echo "Screenshot cancelled"
        end
        return 1
    end
end

# Parameters and defaults
set -l MODE (set -q argv[1]; and echo $argv[1]; or echo "monitor")
set -l DEFAULT_DIR "$HOME/Pictures/Screenshots"
set -l XDG_SCREENSHOTS_DIR (set -q XDG_SCREENSHOTS_DIR; and echo $XDG_SCREENSHOTS_DIR; or echo $DEFAULT_DIR)

mkdir -p "$XDG_SCREENSHOTS_DIR"

set -l APP_NAME (get_app_name)
set -l FILENAME (next_filename "$XDG_SCREENSHOTS_DIR" "$APP_NAME")

switch $MODE
    case monitor full
        take_screenshot output "$XDG_SCREENSHOTS_DIR" "$FILENAME"
    case region area
        take_screenshot region "$XDG_SCREENSHOTS_DIR" "$FILENAME"
    case window active
        take_screenshot window "$XDG_SCREENSHOTS_DIR" "$FILENAME"
    case '*'
        echo "Usage: screenshot [monitor|region|window]"
        echo ""
        echo "Modes:"
        echo "  monitor - Screenshot current monitor (default)"
        echo "  region  - Screenshot selected region"
        echo "  window  - Screenshot active window"
        exit 1
end