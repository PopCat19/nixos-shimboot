# Display Manager Module
#
# Purpose: Configure X server, LightDM, and systemd logind for ChromeOS devices
# Dependencies: lightdm, systemd
# Related: hyprland.nix, hardware.nix, systemd-patch.nix, kill-frecon.nix
#
# This module:
# - Enables X server with basic configuration
# - Configures LightDM display manager without autologin
# - Sets up Hyprland session configuration
# - Manages default session and display settings
# - Configures systemd logind for power management
{
  pkgs,
  lib,
  ...
}:
{
  services.xserver = {
    enable = lib.mkDefault true;
    xkb.layout = lib.mkDefault "us";
    desktopManager.runXdgAutostartIfNone = lib.mkDefault true;
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

  programs.dconf.enable = lib.mkDefault true;

  # Explicitly enable logind to bypass NixOS unstable's default check
  # for systemd.package.withLogind (only exists in 258+, we use 257.9)
  services.logind.enable = true;

  services.logind = {
    settings = {
      Login = {
        HandleLidSwitch = "ignore";
        HandlePowerKey = "ignore";
        HandleSuspendKey = "ignore";
        HandleHibernateKey = "ignore";
      };
    };
  };

  systemd.services.display-manager.after = lib.mkDefault [
    "multi-user.target"
    "systemd-logind.service"
  ];
  systemd.services.display-manager.wants = lib.mkDefault [ ];
}
