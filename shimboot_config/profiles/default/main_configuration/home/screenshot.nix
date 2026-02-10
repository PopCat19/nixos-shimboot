# Screenshot Module
#
# Purpose: Configure screenshot tools and wrapper script for Hyprland using grimblast
# Dependencies: grimblast, gwenview, libnotify, jq
# Related: hypr_config/hyprland.nix (keybinds)
#
# This module:
# - Installs screenshot tools (grimblast, gwenview, libnotify, jq)
# - Creates Screenshots directory
# - Installs screenshot wrapper script with hyprshade integration
{ pkgs, ... }:
let
  # Screenshot wrapper script using grimblast with hyprshade integration
  screenshotScript = pkgs.writeShellScriptBin "screenshot" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    # Configuration
    DEFAULT_DIR="$HOME/Pictures/Screenshots"
    XDG_SCREENSHOTS_DIR="''${XDG_SCREENSHOTS_DIR:-$DEFAULT_DIR}"
    mkdir -p "$XDG_SCREENSHOTS_DIR"

    # Parse arguments
    MODE="output"  # grimblast: output (monitor), area (region), active (window)
    KEEP_SHADER=false
    POSITIONAL_ARGS=()

    while [[ $# -gt 0 ]]; do
      case $1 in
        --keep-shader)
          KEEP_SHADER=true
          shift
          ;;
        -*)
          echo "Unknown option: $1" >&2
          exit 1
          ;;
        *)
          POSITIONAL_ARGS+=("$1")
          shift
          ;;
      esac
    done

    set -- "''${POSITIONAL_ARGS[@]}"

    if [[ $# -gt 0 ]]; then
      case $1 in
        monitor|full) MODE="output" ;;
        region|area) MODE="area" ;;
        window|active) MODE="active" ;;
        both)
          # Special case: take both output and area screenshots
          MODE="both"
          ;;
        *)
          echo "Usage: screenshot [monitor|region|window|both] [--keep-shader]" >&2
          echo ""
          echo "Modes:"
          echo "  monitor - Screenshot current monitor (default)"
          echo "  region  - Screenshot selected region"
          echo "  window  - Screenshot active window"
          echo "  both    - Screenshot both monitor and region"
          echo ""
          echo "Options:"
          echo "  --keep-shader - Preserve hyprshade effects in screenshot"
          exit 1
          ;;
      esac
    fi

    # Helper: Slugify app name
    slugify_app_name() {
      local s="''${1:-}"
      if [[ -z "$s" ]]; then
        echo "screen"
        return
      fi
      s="''${s,,}"  # lowercase
      s="''${s//[^a-z0-9._-]/-}"  # replace invalid chars with dash
      s="''${s//+(-)/-}"  # collapse multiple dashes
      s="''${s#-}"  # trim leading dash
      s="''${s%-}"  # trim trailing dash
      if [[ -z "$s" ]]; then
        echo "screen"
      else
        echo "$s"
      fi
    }

    # Helper: Get app name from hyprctl
    get_app_name() {
      local app="screen"
      if command -v hyprctl >/dev/null 2>&1; then
        local json
        json=$(hyprctl activewindow -j 2>/dev/null || true)
        if [[ -n "$json" ]]; then
          local cls
          cls=$(echo "$json" | ${pkgs.jq}/bin/jq -r '.class // empty' 2>/dev/null || true)
          if [[ -n "$cls" && "$cls" != "null" ]]; then
            app="$cls"
          fi
        fi
      fi
      slugify_app_name "$app"
    }

    # Helper: Generate next incremental filename
    next_filename() {
      local dir="$1"
      local app="$2"
      local date
      date=$(date +%Y%m%d)
      local prefix="''${app}_''${date}-"
      local n=1
      while [[ -e "$dir/$prefix$n.png" ]]; do
        ((n++))
      done
      echo "$prefix$n.png"
    }

    # Helper: Run command with hyprshade workaround
    run_with_hyprshade() {
      local keep_shader="$1"
      shift

      if [[ "$keep_shader" == "true" ]]; then
        "$@"
        return $?
      fi

      if command -v hyprshade >/dev/null 2>&1; then
        local shader
        shader=$(hyprshade current 2>/dev/null || echo "")
        if [[ -n "$shader" && "$shader" != "Off" ]]; then
          hyprshade off >/dev/null 2>&1
          "$@"
          local ret=$?
          hyprshade on "$shader" >/dev/null 2>&1 || true
          return $ret
        fi
      fi

      "$@"
    }

    # Helper: Take screenshot
    take_screenshot() {
      local mode="$1"  # grimblast target: output, area, active
      local dir="$2"
      local filename="$3"
      local keep_shader="$4"
      local screenshot_path="$dir/$filename"

      local grimblast_cmd=(
        ${pkgs.grimblast}/bin/grimblast
        --freeze
        copysave
        "$mode"
        "$screenshot_path"
      )

      if run_with_hyprshade "$keep_shader" "''${grimblast_cmd[@]}"; then
        if [[ -f "$screenshot_path" ]]; then
          # grimblast already handles clipboard, just show notification
          ${pkgs.libnotify}/bin/notify-send \
            "Screenshot" \
            "$mode screenshot saved: $filename" \
            -i camera-photo \
            2>/dev/null || true
          echo "Saved: $screenshot_path"
        else
          echo "Screenshot cancelled - no file created"
          return 1
        fi
      else
        if [[ -f "$screenshot_path" ]]; then
          rm -f "$screenshot_path"
          echo "Screenshot cancelled - cleaned up partial file"
        else
          echo "Screenshot cancelled"
        fi
        return 1
      fi
    }

    # Helper: Take both screenshots
    take_both_screenshots() {
      local dir="$1"
      local base_filename="$2"
      local keep_shader="$3"

      # Extract base name without extension
      local base_name="''${base_filename%.png}"

      # Take output screenshot
      local output_filename="''${base_name}_output.png"
      take_screenshot "output" "$dir" "$output_filename" "$keep_shader"

      # Take area screenshot
      local area_filename="''${base_name}_area.png"
      take_screenshot "area" "$dir" "$area_filename" "$keep_shader"
    }

    # Main execution
    APP_NAME=$(get_app_name)
    FILENAME=$(next_filename "$XDG_SCREENSHOTS_DIR" "$APP_NAME")

    case "$MODE" in
      output|area|active)
        take_screenshot "$MODE" "$XDG_SCREENSHOTS_DIR" "$FILENAME" "$KEEP_SHADER"
        ;;
      both)
        take_both_screenshots "$XDG_SCREENSHOTS_DIR" "$FILENAME" "$KEEP_SHADER"
        ;;
    esac
  '';
in
{
  home.packages = with pkgs; [
    grimblast # Primary screenshot tool (more reliable than hyprshot)
    kdePackages.gwenview
    libnotify
    jq
    screenshotScript # Unified screenshot wrapper script
  ];

  home.file."Pictures/Screenshots/.keep".text = "";
}
