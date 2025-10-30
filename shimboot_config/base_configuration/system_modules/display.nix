# Display Configuration Module
#
# Purpose: Configure display server and window manager for ChromeOS devices
# Dependencies: hyprland, lightdm, xdg-desktop-portal
# Related: hardware.nix, services.nix
#
# This module:
# - Enables Hyprland as the default window manager
# - Configures LightDM display manager without autologin
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
    desktopManager.runXdgAutostartIfNone = lib.mkDefault true;
  };

  programs.hyprland = {
    enable = lib.mkDefault true;
    xwayland.enable = lib.mkDefault true;
  };

  services.xserver.displayManager.lightdm = {
    enable = lib.mkDefault true;
    greeters.gtk.enable = lib.mkDefault true;
  };

  services.xserver.displayManager.session = [
    {
      manage = "window";
      name = "hyprland";
      start = ''
        ${pkgs.hyprland}/bin/Hyprland
      '';
    }
  ];

  services.displayManager.defaultSession = lib.mkDefault "hyprland";

  environment.sessionVariables = {
    NIXOS_OZONE_WL = lib.mkDefault "1";
  };

  xdg.mime.enable = lib.mkDefault true;
  xdg.portal = {
    enable = lib.mkDefault true;
    xdgOpenUsePortal = lib.mkDefault true;
    extraPortals = [
      pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-gtk
    ];
    # choose handlers; Hyprland first, fallback to GTK; default GTK for non-Hyprland
    config = {
      common = { default = [ "gtk" ]; };
      hyprland = { default = [ "hyprland" "gtk" ]; };
    };
  };
  
  # Ensure portal starts with session
  systemd.user.services.xdg-desktop-portal-hyprland = {
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
  };

  programs.dconf.enable = lib.mkDefault true;

  environment.systemPackages = with pkgs; [
    brightnessctl
    kitty # required for the default Hyprland config
  ];
}
