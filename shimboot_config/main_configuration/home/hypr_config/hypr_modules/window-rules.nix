# Window Rules Configuration
#
# Purpose: Configure window behavior rules for specific applications
# Dependencies: None
# Related: keybinds.nix, general.nix
#
# This module:
# - Suppresses maximize events globally
# - Defines floating rules for specific applications
# - Sets minimum window sizes
# - Configures focus behavior for special windows
{
  wayland.windowManager.hyprland.settings = {
    windowrulev2 = [
      "suppressevent maximize, class:.*"
      "nofocus,class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0"
      "minsize 1024 600,class:^(org.pulseaudio.pavucontrol)$"

      "float,class:^(org.kde.dolphin)$,title:^(Progress Dialog — Dolphin)$"
      "float,class:^(org.kde.dolphin)$,title:^(Copying — Dolphin)$"
      "float,title:^(About Mozilla Firefox)$"
      "float,class:^(firefox)$,title:^(Picture-in-Picture)$"
      "float,class:^(firefox)$,title:^(Library)$"
      "float,class:^(kitty)$,title:^(top)$"
      "float,class:^(kitty)$,title:^(btop)$"
      "float,class:^(kitty)$,title:^(htop)$"
      "float,class:^(vlc)$"
      "float,class:^(mpv)$"
      "float,class:^(kvantummanager)$"
      "float,class:^(qt5ct)$"
      "float,class:^(qt6ct)$"
      "float,class:^(nwg-look)$"
      "float,class:^(org.kde.ark)$"
      "float,class:^(org.pulseaudio.pavucontrol)$"
      "float,class:^(blueman-manager)$"
      "float,class:^(nm-applet)$"
      "float,class:^(nm-connection-editor)$"
      "float,class:^(org.kde.polkit-kde-authentication-agent-1)$"
      "float,class:^(Signal)$"
      "float,class:^(com.github.rafostar.Clapper)$"
      "float,class:^(app.drey.Warp)$"
      "float,class:^(net.davidotek.pupgui2)$"
      "float,class:^(yad)$"
      "float,class:^(eog)$"
      "float,class:^(org.kde.gwenview)$"
      "float,class:^(io.github.alainm23.planify)$"
      "float,class:^(io.gitlab.theevilskeleton.Upscaler)$"
      "float,class:^(com.github.unrud.VideoDownloader)$"
      "float,class:^(io.gitlab.adhami3310.Impression)$"
      "float,class:^(io.missioncenter.MissionCenter)$"
      "float, class:Waydroid"
      "float,class:^(xdg-desktop-portal-gtk)$"
      "float,class:^(org.keepassxc.KeePassXC)$,title:^(Password Generator)$"
      "float,class:^(keepassxc)$,title:^(Password Generator)$"

      "float, title:^(Open)$"
      "float, title:^(Choose Files)$"
      "float, title:^(Save As)$"
      "float, title:^(Confirm to replace files)$"
      "float, title:^(File Operation Progress)$"
    ];
  };
}
