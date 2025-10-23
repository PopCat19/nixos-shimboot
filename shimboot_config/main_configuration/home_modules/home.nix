{...}: {
  # General Home Manager settings and user-level imports
  imports = [
    ../hypr_config/hyprland.nix
    ../hypr_config/hyprpanel-common.nix
    ../hypr_config/hyprpanel-home.nix
    ../hypr_config/hypr_packages.nix

    # Split modules
    ./environment.nix
    ./fish.nix
    ./packages.nix
    ./starship.nix
    ./zen-browser.nix

    # Additional home modules that were orphaned
    ./fcitx5.nix
    ./kde.nix
    ./kitty.nix
    ./micro.nix
    ./privacy.nix
    ./qt-gtk-config.nix
    ./screenshot.nix
    ./theme.nix
  ];

  home.stateVersion = "24.11";
}
