{ config, pkgs, ... }:

{
  # Screenshot configuration for Hyprland using grimblast

  home.packages = with pkgs; [
    # Core screenshot tools
    hyprshot                           # Primary screenshot tool for Hyprland
    kdePackages.gwenview               # Image viewer
    libnotify                          # Desktop notifications (notify-send)
    jq                                 # For parsing hyprctl JSON (app name)
  ];

  # Create Screenshots directory
  home.file."Pictures/Screenshots/.keep".text = "";

  # Screenshot wrapper script for hyprshot with hyprshade integration
  home.file.".local/bin/screenshot" = {
    source = ./screenshot.fish;
    executable = true;
  };
}