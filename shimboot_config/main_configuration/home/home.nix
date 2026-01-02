# Home Manager Configuration Module
#
# Purpose: Main Home Manager configuration combining all user modules
# Dependencies: All home modules, hypr_config modules
# Related: configuration.nix, user-config.nix
#
# This module:
# - Imports all Home Manager modules
# - Configures desktop environment
# - Sets Home Manager state version
{...}: {
  imports = [
    ./hypr_config/hyprland.nix
    ./noctalia_config/noctalia.nix
    ./hypr_config/hypr_packages.nix

    ./environment.nix
    # Fish and Starship are configured in base_configuration/system_modules/
    ./fish-themes.nix
    ./packages.nix
    ./services.nix
    # Starship is configured in base_configuration/system_modules/fish.nix
    ./zen-browser.nix

    ./fcitx5.nix
    ./dolphin.nix
    ./fuzzel.nix
    ./bookmarks.nix
    ./kde.nix
    ./kitty.nix
    ./micro.nix
    ./privacy.nix
    ./screenshot.nix
    ./stylix.nix
    ./vesktop.nix
    ./vscodium.nix
  ];

  home.stateVersion = "24.11";
}
