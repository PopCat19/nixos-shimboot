{ ... }: {
  # General Home Manager settings and user-level imports
  imports = [
    ../hypr_config/hyprland.nix
    ../hypr_config/hyprpanel-common.nix
    ../hypr_config/hyprpanel-home.nix
    ../hypr_config/hypr_packages.nix

    # Split modules
    ./environment.nix
    ./programs.nix
    ./packages.nix
    ./starship.nix
    ./zen-browser.nix

    # Additional home modules that were orphaned
    ./fcitx5.nix
    ./kde.nix
    ./kitty.nix
    ./micro.nix
    ./qt-gtk-config.nix
    ./theme.nix
  ];

  home.stateVersion = "24.11";
}