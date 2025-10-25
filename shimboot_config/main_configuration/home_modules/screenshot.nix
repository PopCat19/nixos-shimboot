# Screenshot Module
#
# Purpose: Configure screenshot tools and wrapper script for Hyprland
# Dependencies: hyprshot, screenshot.fish
# Related: hypr_config/hyprland.nix
#
# This module:
# - Installs screenshot tools (hyprshot, gwenview, libnotify, jq)
# - Creates Screenshots directory
# - Installs screenshot wrapper script with hyprshade integration
{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    hyprshot
    kdePackages.gwenview
    libnotify
    jq
  ];

  home.file."Pictures/Screenshots/.keep".text = "";

  home.file.".local/bin/screenshot" = {
    source = ./screenshot.fish;
    executable = true;
  };
}
