# screenshot.nix
#
# Purpose: Provide simple hyprshot wrapper with shader-safe freeze handling
#
# This module:
# - Installs hyprshot
# - Creates minimal screenshot wrapper
{ pkgs, ... }:
let
  screenshotScript = pkgs.writeShellScriptBin "screenshot" ''
    set -euo pipefail

    SCREENSHOTS_DIR="''${XDG_SCREENSHOTS_DIR:-$HOME/Pictures/Screenshots}"
    mkdir -p "$SCREENSHOTS_DIR"

    MODE="output"

    case "''${1:-monitor}" in
      monitor) MODE="output" ;;
      region) MODE="region" ;;
      window) MODE="window" ;;
      *) echo "Unknown mode: $1" >&2; exit 1 ;;
    esac

    FILE="$(date +%Y-%m-%d_%H-%M-%S).png"

    SHADER=""
    RESTORE=0

    if command -v hyprshade >/dev/null 2>&1; then
      SHADER=$(hyprshade current 2>/dev/null || true)
    fi

    ${pkgs.hyprshot}/bin/hyprshot \
      --mode "$MODE" \
      --freeze \
      -o "$SCREENSHOTS_DIR" \
      -f "$FILE" &
    pid=$!

    if [[ -n "$SHADER" && "$SHADER" != "Off" ]]; then
      sleep 0.01
      hyprshade off >/dev/null 2>&1 || true
      RESTORE=1
    fi

    wait "$pid"

    if [[ "$RESTORE" = 1 ]]; then
      hyprshade on "$SHADER" >/dev/null 2>&1 || true
    fi
  '';
in
{
  home.file."Pictures/Screenshots/.keep".text = "";

  home.packages = with pkgs; [
    hyprshot
    screenshotScript
  ];
}
