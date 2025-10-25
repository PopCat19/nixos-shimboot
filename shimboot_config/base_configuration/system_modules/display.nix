# Display Configuration Module
#
# Purpose: Configure display server and window manager for ChromeOS devices
# Dependencies: hyprland, greetd, xdg-desktop-portal
# Related: hardware.nix, services.nix
#
# This module:
# - Enables Hyprland as the default window manager
# - Configures greetd display manager with tuigreet for manual login
# - Sets up XDG portals for Wayland compatibility
# - Enables brightness control and display tools
{
  config,
  pkgs,
  lib,
  userConfig,
  ...
}: {
  services.xserver = {
    enable = lib.mkDefault true;
    xkb.layout = lib.mkDefault "us";
  };

  programs.hyprland = {
    enable = lib.mkDefault true;
    xwayland.enable = lib.mkDefault true;
  };

  # Replace LightDM with greetd + tuigreet
  services.greetd = {
    enable = lib.mkDefault true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd Hyprland";
        user = "greeter";
      };
    };
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = lib.mkDefault "1";
  };

  xdg = {
    mime.enable = lib.mkDefault true;
    portal = {
      enable = lib.mkDefault true;
      xdgOpenUsePortal = lib.mkDefault true;
      extraPortals = [
        pkgs.xdg-desktop-portal-hyprland
      ];
    };
  };

  programs.dconf.enable = lib.mkDefault true;

  environment.systemPackages = with pkgs; [
    brightnessctl
  ];
}
