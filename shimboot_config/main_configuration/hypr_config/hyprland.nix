{ config, pkgs, lib, ... }:

{
  imports = [
    ./hypr_modules/colors.nix
    ./hypr_modules/environment.nix
    ./hypr_modules/autostart.nix
    ./hypr_modules/general.nix
    ./hypr_modules/animations.nix
    ./hypr_modules/keybinds.nix
    ./hypr_modules/window-rules.nix
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    
    settings = {
      source = [
        "~/.config/hypr/monitors.conf"
        "~/.config/hypr/userprefs.conf"
      ];
    };
  };

  home.file = {
    ".config/hypr/monitors.conf".source = ./monitors.conf;
    ".config/hypr/userprefs.conf".source = ./userprefs.conf;
    ".config/hypr/hyprpaper.conf".source = ./hyprpaper.conf;
    ".config/hypr/shaders" = {
      source = ./shaders;
      recursive = true;
    };
  };
}