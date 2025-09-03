{ config, pkgs, lib, userConfig, ... }:

{
  # X server basics (not strictly required for Hyprland, but harmless)
  services.xserver = {
    enable = lib.mkDefault true;
    xkb.layout = lib.mkDefault "us";
    desktopManager.runXdgAutostartIfNone = lib.mkDefault true;
  };

  # Hyprland via UWSM
  programs.hyprland = {
    enable = lib.mkDefault true;
    xwayland.enable = lib.mkDefault true;
  };

  # Wayland-native autologin via greetd (replaces LightDM)
  services.greetd = {
    enable = lib.mkDefault true;
    settings = {
      default_session = {
        command = "${pkgs.hyprland}/bin/Hyprland";
        user = lib.mkForce userConfig.user.username;
      };
    };
  };

  # Wayland-friendly defaults for Electron/Chromium apps
  environment.sessionVariables = {
    NIXOS_OZONE_WL = lib.mkDefault "1";
  };

  # Portals for screenshare, file pickers, etc.
  xdg = {
    mime.enable = lib.mkDefault true;
    portal = {
      enable = lib.mkDefault true;
      xdgOpenUsePortal = lib.mkDefault true;
      extraPortals = [
        pkgs.xdg-desktop-portal-hyprland
        pkgs.xdg-desktop-portal-gtk
      ];
    };
  };

  programs.dconf.enable = lib.mkDefault true;

  # Ensure basic tools are available
  environment.systemPackages = with pkgs; [
    brightnessctl
  ];
}