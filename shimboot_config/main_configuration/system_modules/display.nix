# Display Module
#
# Purpose: Configure Hyprland window manager and display services
# Dependencies: userConfig
# Related: hypr_config/hyprland.nix
#
# This module:
# - Enables Hyprland with XWayland support
# - Configures LightDM display manager
# - Sets up Wayland environment variables
{
  config,
  pkgs,
  lib,
  userConfig,
  ...
}: {
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  services = {
    xserver = {
      enable = true;
      displayManager = {
        lightdm = {
          enable = true;
          greeters = {
            gtk = {
              enable = true;
            };
          };
        };
        session = [
          {
            manage = "window";
            name = "hyprland";
            start = ''
              ${pkgs.hyprland}/bin/Hyprland
            '';
          }
        ];
      };
      xkb.layout = "us";
      # Let X11 auto-detect the video driver
      # Hyprland doesn't use xserver.videoDrivers anyway
    };
    displayManager = {
      defaultSession = "hyprland";
      autoLogin.enable = false;
    };
  };

  environment.systemPackages = with pkgs; [
    brightnessctl
    lightdm
    lightdm-gtk-greeter
  ];
}
