{
  config,
  pkgs,
  lib,
  userConfig,
  ...
}: {
  # Ensure main takes precedence over base's defaults
  # greetd is enabled in the services.greetd block below

  # Display Manager and Desktop Environment Configuration
  programs.hyprland = {
    # or wayland.windowManager.hyprland
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
          greeters = {
            gtk = {
              enable = true;
            };
          };
        };
        # Provide Hyprland session entry for LightDM
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
      videoDrivers = ["intel"]; # Video drivers
    };
    # Explicitly disable autologin
    displayManager = {
      defaultSession = "hyprland";
      autoLogin.enable = false;
    };
  };

  # Ensure basic tools are available
  environment.systemPackages = with pkgs; [
    brightnessctl
    lightdm # Display manager
    lightdm-gtk-greeter # LightDM greeter
  ];
}
