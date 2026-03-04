# screenshot.nix
#
# Purpose: Provide simple hyprshot wrapper with predictable hyprshade handling
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
    INCLUDE_SHADER=false

    while [[ $# -gt 0 ]]; do
      case "$1" in
        monitor|"") MODE="output" ;;
        region) MODE="region" ;;
        window) MODE="window" ;;
        --include-shader) INCLUDE_SHADER=true ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
      esac
      shift
    done

    SHADER=""
    if command -v hyprshade >/dev/null 2>&1; then
      SHADER=$(hyprshade current 2>/dev/null || true)
    fi

    if [[ -n "$SHADER" && "$SHADER" != "Off" ]]; then
      if [[ "$INCLUDE_SHADER" = true ]]; then
        hyprshade on "$SHADER" >/dev/null 2>&1 || true
        hyprshade off >/dev/null 2>&1 || true
        hyprshot -m "$MODE" -o "$SCREENSHOTS_DIR"
        sleep 0.1
        hyprshade on "$SHADER" >/dev/null 2>&1 || true
      else
        hyprshade off >/dev/null 2>&1 || true
        hyprshot -m "$MODE" -o "$SCREENSHOTS_DIR"
        hyprshade on "$SHADER" >/dev/null 2>&1 || true
      fi
    else
      hyprshot -m "$MODE" -o "$SCREENSHOTS_DIR"
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
