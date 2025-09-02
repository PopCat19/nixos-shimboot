{ ... }: {
  # General Home Manager settings and user-level imports
  imports = [
    ./hypr_config/hyprland.nix
    ./hypr_config/hyprpanel-common.nix
    ./hypr_config/hyprpanel-home.nix

    # Split modules
    ./programs.nix
    ./packages.nix
  ];

  home.stateVersion = "24.11";
}