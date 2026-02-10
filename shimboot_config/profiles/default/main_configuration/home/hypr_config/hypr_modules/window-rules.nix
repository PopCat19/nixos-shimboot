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
    windowrule = [
      # Global rules
      "suppress_event maximize, match:class .*"
      "no_focus on, match:class ^$, match:title ^$, match:xwayland 1, match:float 1, match:fullscreen 0, match:pin 0"
      "min_size 1024 600, match:class ^(org.pulseaudio.pavucontrol)$"

      # Floating rules - Dolphin
      "float on, match:class ^(org.kde.dolphin)$, match:title ^(Progress Dialog — Dolphin)$"
      "float on, match:class ^(org.kde.dolphin)$, match:title ^(Copying — Dolphin)$"

      # Floating rules - Firefox
      "float on, match:title ^(About Mozilla Firefox)$"
      "float on, match:class ^(firefox)$, match:title ^(Picture-in-Picture)$"
      "float on, match:class ^(firefox)$, match:title ^(Library)$"

      # Floating rules - Kitty
      "float on, match:class ^(kitty)$, match:title ^(top)$"
      "float on, match:class ^(kitty)$, match:title ^(btop)$"
      "float on, match:class ^(kitty)$, match:title ^(htop)$"

      # Floating rules - Media players
      "float on, match:class ^(vlc)$"
      "float on, match:class ^(mpv)$"

      # Floating rules - Qt/KDE apps
      "float on, match:class ^(kvantummanager)$"
      "float on, match:class ^(qt5ct)$"
      "float on, match:class ^(qt6ct)$"
      "float on, match:class ^(nwg-look)$"
      "float on, match:class ^(org.kde.ark)$"

      # Floating rules - System apps
      "float on, match:class ^(org.pulseaudio.pavucontrol)$"
      "float on, match:class ^(blueman-manager)$"
      "float on, match:class ^(nm-applet)$"
      "float on, match:class ^(nm-connection-editor)$"
      "float on, match:class ^(org.kde.polkit-kde-authentication-agent-1)$"

      # Floating rules - Communication/GUI apps
      "float on, match:class ^(Signal)$"
      "float on, match:class ^(com.github.rafostar.Clapper)$"
      "float on, match:class ^(app.drey.Warp)$"
      "float on, match:class ^(net.davidotek.pupgui2)$"
      "float on, match:class ^(yad)$"
      "float on, match:class ^(eog)$"
      "float on, match:class ^(org.kde.gwenview)$"
      "float on, match:class ^(io.github.alainm23.planify)$"
      "float on, match:class ^(io.gitlab.theevilskeleton.Upscaler)$"
      "float on, match:class ^(com.github.unrud.VideoDownloader)$"
      "float on, match:class ^(io.gitlab.adhami3310.Impression)$"
      "float on, match:class ^(io.missioncenter.MissionCenter)$"
      "float on, match:class Waydroid"
      "float on, match:class ^(xdg-desktop-portal-gtk)$"

      # Floating rules - KeepassXC
      "float on, match:class ^(org.keepassxc.KeePassXC)$, match:title ^(Password Generator)$"
      "float on, match:class ^(keepassxc)$, match:title ^(Password Generator)$"

      # Floating rules - File dialogs
      "float on, match:title ^(Open)$"
      "float on, match:title ^(Choose Files)$"
      "float on, match:title ^(Save As)$"
      "float on, match:title ^(Confirm to replace files)$"
      "float on, match:title ^(File Operation Progress)$"
    ];
  };
}
