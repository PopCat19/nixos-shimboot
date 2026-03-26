# Services Module
#
# Purpose: Configure user-level services for media, storage, and utilities
# Dependencies: None
# Related: None
#
# This module:
# - Enables media player control services
# - Configures storage management and clipboard tools
# - Sets up audio effects processing
{ pkgs, ... }:
{
  services = {
    playerctld.enable = true;
    udiskie.enable = true;
    easyeffects.enable = true;
  };

  home.packages = [ pkgs.cliphist ];

  xdg.configFile."systemd/user/xdg-desktop-portal-hyprland.service.d/override.conf".text = ''
    [Unit]
    After=hyprland-session.target
    ConditionEnvironment=

    [Install]
    WantedBy=hyprland-session.target
  '';

  xdg.configFile."systemd/user/xdg-desktop-portal.service.d/override.conf".text = ''
    [Unit]
    After=xdg-desktop-portal-hyprland.service xdg-desktop-portal-gtk.service
    Wants=xdg-desktop-portal-hyprland.service xdg-desktop-portal-gtk.service
  '';
}
