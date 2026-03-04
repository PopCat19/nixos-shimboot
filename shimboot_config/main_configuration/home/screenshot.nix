# screenshot.nix
#
# Purpose: Provide simple hyprshot wrapper with optional shader disable
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
    EXCLUDE_SHADER=false

    while [[ $# -gt 0 ]]; do
      case "$1" in
        monitor|"") MODE="output" ;;
        region) MODE="region" ;;
        window) MODE="window" ;;
        --exclude-shader) EXCLUDE_SHADER=true ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
      esac
      shift
    done

    SAVED_SHADER=""
    RESTORE=0

    if [[ "$EXCLUDE_SHADER" = true ]] && command -v hyprshade >/dev/null 2>&1; then
      SAVED_SHADER=$(hyprshade current 2>/dev/null || true)

      if [[ -n "$SAVED_SHADER" && "$SAVED_SHADER" != "Off" ]]; then
        hyprshade off >/dev/null 2>&1 || true
        sleep 0.1
        RESTORE=1
      fi
    fi

    hyprshot -m "$MODE" -o "$SCREENSHOTS_DIR"

    if [[ "$RESTORE" = 1 ]]; then
      hyprshade on "$SAVED_SHADER" >/dev/null 2>&1 || true
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
