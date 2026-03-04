# screenshot.nix
#
# Purpose: Configure screenshot tools and wrapper script for Hyprland
#
# This module:
# - Installs screenshot tools (grimblast, gwenview, libnotify, jq)
# - Creates wrapper script with hyprshade integration
{ pkgs, ... }:
let
  screenshotScript = pkgs.writeShellScriptBin "screenshot" ''
    set -euo pipefail

    SCREENSHOTS_DIR="''${XDG_SCREENSHOTS_DIR:-$HOME/Pictures/Screenshots}"
    mkdir -p "$SCREENSHOTS_DIR"

    MODE="output"
    KEEP_SHADER=false

    usage() {
      echo "Usage: screenshot [monitor|region|window|both] [--keep-shader]"
      echo ""
      echo "Modes:"
      echo "  monitor   Capture the current output (default)"
      echo "  region    Select a region to capture"
      echo "  window    Capture the active window"
      echo "  both      Capture output, then select a region"
      echo ""
      echo "Options:"
      echo "  --keep-shader   Don't disable hyprshade during capture"
      exit 0
    }

    while [[ $# -gt 0 ]]; do
      case $1 in
        --keep-shader)  KEEP_SHADER=true ;;
        --help|-h)      usage ;;
        -*)             echo "Unknown option: $1" >&2; exit 1 ;;
        monitor|"")     MODE="output" ;;
        region)         MODE="area" ;;
        window)         MODE="active" ;;
        both)           MODE="both" ;;
        *)              echo "Error: unknown mode '$1'" >&2; exit 1 ;;
      esac
      shift
    done

    # -- Hyprshade management --------------------------------------------------

    SAVED_SHADER=""

    save_hyprshade() {
      if [[ "$KEEP_SHADER" == "true" ]]; then
        return
      fi
      if ! command -v hyprshade >/dev/null 2>&1; then
        return
      fi
      SAVED_SHADER=$(hyprshade current 2>/dev/null || true)
      if [[ -n "$SAVED_SHADER" && "$SAVED_SHADER" != "Off" ]]; then
        hyprshade off >/dev/null 2>&1 || true
        sleep 0.15
      else
        SAVED_SHADER=""
      fi
    }

    restore_hyprshade() {
      if [[ -n "$SAVED_SHADER" ]]; then
        local shader="$SAVED_SHADER"
        SAVED_SHADER=""
        hyprshade on "$shader" >/dev/null 2>&1 || true
      fi
    }

    trap restore_hyprshade EXIT

    # -- Helpers ---------------------------------------------------------------

    get_app_name() {
      if command -v hyprctl >/dev/null 2>&1; then
        hyprctl activewindow -j 2>/dev/null \
          | ${pkgs.jq}/bin/jq -r '.class // "screen"' 2>/dev/null \
          | tr '[:upper:]' '[:lower:]' \
          | tr -c 'a-z0-9._-' '-'
      else
        echo "screen"
      fi
    }

    next_filename() {
      local dir="$1" app="$2" suffix="''${3:-}"
      local date
      date=$(date +%Y%m%d)
      local prefix="''${app}_''${date}-"
      local n=1
      while [[ -e "$dir/''${prefix}''${n}''${suffix}.png" ]]; do
        ((n++))
      done
      echo "''${prefix}''${n}''${suffix}.png"
    }

    take_screenshot() {
      local mode="$1" dir="$2" filename="$3"
      local filepath="$dir/$filename"

      local -a cmd=(${pkgs.grimblast}/bin/grimblast)
      [[ "$mode" == "area" ]] && cmd+=(--freeze)
      cmd+=(copysave "$mode" "$filepath")

      if "''${cmd[@]}" && [[ -f "$filepath" ]]; then
        ${pkgs.libnotify}/bin/notify-send \
          "Screenshot" "$filename saved" \
          -i camera-photo 2>/dev/null || true
        echo "Saved: $filepath"
        return 0
      fi

      rm -f "$filepath"
      echo "Screenshot cancelled ($mode)" >&2
      return 1
    }

    # -- Main ------------------------------------------------------------------

    APP_NAME=$(get_app_name)
    save_hyprshade

    case "$MODE" in
      output|area|active)
        FILENAME=$(next_filename "$SCREENSHOTS_DIR" "$APP_NAME")
        take_screenshot "$MODE" "$SCREENSHOTS_DIR" "$FILENAME"
        ;;
      both)
        FILENAME=$(next_filename "$SCREENSHOTS_DIR" "$APP_NAME" "_output")
        take_screenshot "output" "$SCREENSHOTS_DIR" "$FILENAME"

        FILENAME=$(next_filename "$SCREENSHOTS_DIR" "$APP_NAME" "_area")
        take_screenshot "area" "$SCREENSHOTS_DIR" "$FILENAME"
        ;;
    esac
  '';
in
{
  home.file."Pictures/Screenshots/.keep".text = "";

  home.packages = with pkgs; [
    grimblast
    jq
    kdePackages.gwenview
    libnotify
    screenshotScript
  ];
}
