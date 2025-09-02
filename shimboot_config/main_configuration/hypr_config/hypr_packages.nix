{ pkgs, ... }: {
  home.packages = with pkgs; [
    hyprland
    hyprshade
    hyprpaper
    hyprpolkitagent
    hyprutils
    hyprpanel
    xdg-desktop-portal-hyprland
  ];
}