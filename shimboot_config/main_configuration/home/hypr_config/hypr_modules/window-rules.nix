# Hyprland Window Rules Module
#
# Purpose: Define window behavior rules for specific applications in Hyprland
# Dependencies: theme_config/window-rules.nix
# Related: general.nix
#
# This module:
# - Imports centralized window rules and opacity settings from theme_config
# - Maintains backward compatibility for existing imports
# - Provides window behavior configuration for Hyprland
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: {
  wayland.windowManager.hyprland.settings = {
    # Generate window rules directly since theme_config/window-rules.nix is now a module
    windowrulev2 = let
      # General window rules
      generalRules = [
        "suppressevent maximize, class:.*"
        "nofocus,class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0"
        "minsize 1024 600,class:^(org.pulseaudio.pavucontrol)$"
      ];

      # Application opacity rules
      mkOpacityRules = category: opacityValues: map (class: "opacity ${toString opacityValues.regular} ${toString opacityValues.inactive},class:^(${class})$") category;

      standardOpacity = [
        "opacity 0.85 0.85,class:^(code-oss)$"
        "opacity 0.85 0.85,class:^([Cc]ode)$"
        "opacity 0.85 0.85,class:^(code-url-handler)$"
        "opacity 0.85 0.85,class:^(code-insiders-url-handler)$"
        "opacity 0.85 0.85,class:^(kitty)$"
        "opacity 0.85 0.85,class:^(org.kde.dolphin)$"
        "opacity 0.85 0.85,class:^(org.kde.ark)$"
        "opacity 0.85 0.85,class:^(nemo)$"
        "opacity 0.85 0.85,class:^(nautilus)$"
      ];

      utilitiesOpacity = [
        "opacity 0.85 0.75,class:^(org.pulseaudio.pavucontrol)$"
        "opacity 0.85 0.75,class:^(blueman-manager)$"
        "opacity 0.85 0.75,class:^(nm-applet)$"
        "opacity 0.85 0.75,class:^(nm-connection-editor)$"
      ];

      mediaOpacity = [
        "opacity 0.75 0.75,class:^([Ss]team)$"
        "opacity 0.75 0.75,class:^(steamwebhelper)$"
        "opacity 0.75 0.75,class:^([Ss]potify)$"
      ];

      # Floating window rules
      floatingRules = [
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
        "float,class:^(org.pulseaudio.pavucontrol)$"
        "float,class:^(Signal)$"
        "float,title:^(Open)$"
        "float,title:^(Choose Files)$"
        "float,title:^(Save As)$"
        "float,title:^(Confirm to replace files)$"
        "float,title:^(File Operation Progress)$"
      ];
    in
      generalRules ++ standardOpacity ++ utilitiesOpacity ++ mediaOpacity ++ floatingRules;

    windowrule = [
      "float,title:^(Open)$"
      "float,title:^(Choose Files)$"
      "float,title:^(Save As)$"
      "float,title:^(Confirm to replace files)$"
      "float,title:^(File Operation Progress)$"
    ];
  };
}
