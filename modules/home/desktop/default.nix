# Desktop Environment Modules
#
# Purpose: Bundle desktop environment and GUI applications
# Dependencies: All desktop modules in this directory
# Related: modules/home/core, modules/home/cli
#
# This bundle:
# - Configures Hyprland window manager
# - Sets up KDE components
# - Configures Dolphin file manager
# - Sets up screenshot functionality
# - Configures bookmarks
{ ... }:
{
  imports = [
    ./hyprland
    ./screenshot.nix
    ./kde.nix
    ./dolphin.nix
    ./bookmarks.nix
  ];
}
