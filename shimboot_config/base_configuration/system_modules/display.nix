{ pkgs, ... }:

{
  services.xserver = {
    enable = true;
    xkb.layout = "us";
    desktopManager.runXdgAutostartIfNone = true;
  };

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    withUWSM = true;
  };
  programs.uwsm.enable = true;

  xdg = {
    mime.enable = true;
    portal = {
      enable = true;
    };
  };

  # Display manager configuration moved to main configuration
  # to avoid conflicts between SDDM and LightDM

  programs.dconf.enable = true;
}