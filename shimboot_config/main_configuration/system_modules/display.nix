{ config, pkgs, lib, userConfig, ... }:

{
  # Ensure main takes precedence over base's defaults
  # greetd is enabled in the services.greetd block below

  # Display Manager and Desktop Environment Configuration
  programs.hyprland = { # or wayland.windowManager.hyprland
      enable = true;
      xwayland.enable = true;
    };

  # Configure user session environment for Hyprland
  environment.sessionVariables = {
    # Hints Electron apps to use Wayland
    NIXOS_OZONE_WL = "1";
  };

  # Services Configuration
  services = {
    xserver = {
      enable = true; # Keep X server for Xwayland; no display manager when using greetd
      xkb.layout = "us"; # Keyboard layout
      videoDrivers = [ "intel" ]; # Video drivers
    };
    greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.hyprland}/bin/Hyprland";
          user = lib.mkForce userConfig.user.username;
        };
      };
    };
  };
  
  # Ensure basic tools are available
  environment.systemPackages = with pkgs; [
    brightnessctl
  ];
}