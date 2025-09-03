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

  # LightDM for minimal/base: autologin to Hyprland via UWSM
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
  services.displayManager.autoLogin = {
    enable = lib.mkDefault true;
    user = lib.mkDefault userConfig.user.username;
    # Reduce race with greeter showing before autologin kicks in
    
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
    lightdm     # Display manager
    lightdm-gtk-greeter # LightDM greeter
  ];
}