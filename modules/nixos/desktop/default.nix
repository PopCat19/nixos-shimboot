# Desktop Environment Modules
#
# Purpose: Bundle all desktop environment configuration modules
# Dependencies: All desktop modules in this directory
# Related: modules/nixos/core, modules/nixos/hardware
#
# This bundle:
# - Configures display manager
# - Sets up XDG portals
# - Configures fonts
# - Enables Hyprland
# - Configures initial setup experience
{
  imports = [
    ./display-manager.nix
    ./xdg-portals.nix
    ./fonts.nix
    ./hyprland.nix
    ./setup-experience.nix
  ];
}
