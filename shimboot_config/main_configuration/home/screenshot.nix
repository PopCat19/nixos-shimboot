# screenshot.nix
#
# Purpose: Provide simple hyprshot wrapper with predictable shader handling
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
      *) echo "Usage: screenshot [monitor|region|window]" >&2; exit 1 ;;
    esac

    shader=""
    restore_shader() {
      if [[ -n "$shader" && "$shader" != "Off" ]]; then
        hyprshade on "$shader"
      fi
    }

    if command -v hyprshade >/dev/null 2>&1; then
      shader=$(hyprshade current 2>/dev/null || true)
      if [[ -n "$shader" && "$shader" != "Off" ]]; then
        hyprshade off
        trap restore_shader EXIT
      fi
    fi

    ${pkgs.hyprshot}/bin/hyprshot \
      --freeze \
      --mode "$MODE" \
      -o "$SCREENSHOTS_DIR"
  '';
in
{
  home.file."Pictures/Screenshots/.keep".text = "";

  home.packages = with pkgs; [
    hyprshot
    screenshotScript
  ];
}
