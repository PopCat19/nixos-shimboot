{ config, pkgs, lib, userConfig, ... }:

{
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
      enable = true; # Enable X server for LightDM
      displayManager = {
        lightdm = {
          enable = true;
          # Configure LightDM greeter
          greeters = {
            gtk = {
              enable = true;
            };
          };
        };
        # Configure display manager session
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
      xkb.layout = "us"; # Keyboard layout
      videoDrivers = [ "intel" ]; # Video drivers
    };
    # Configure default session and auto-login (this is separate from the LightDM configuration)
    displayManager = {
      defaultSession = "hyprland-uwsm";
      autoLogin = {
        enable = true;
        user = userConfig.user.username;
      };
    };
  };
  
  # Ensure basic tools are available
  environment.systemPackages = with pkgs; [
    brightnessctl
    lightdm     # Display manager
    lightdm-gtk-greeter # LightDM greeter
  ];
}