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
    withUWSM = lib.mkDefault true;
  };
  programs.uwsm.enable = lib.mkDefault true;

  # Minimal greeter: greetd autologin to Hyprland via UWSM (defaulted, guard with enable)
  services.greetd = {
    enable = lib.mkDefault true;

    # Only define settings when greetd is enabled (prevents merging when main disables it)
    settings = lib.mkIf config.services.greetd.enable {
      default_session = {
        command = lib.mkDefault "${pkgs.uwsm}/bin/uwsm start hyprland-uwsm";
        # Upstream defaults to "greeter"; force our autologin user to avoid equal-priority conflicts
        user = lib.mkForce userConfig.user.username;
      };
      # initial_session helps on TTY after logouts
      initial_session = {
        command = lib.mkDefault "${pkgs.uwsm}/bin/uwsm start hyprland-uwsm";
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
}