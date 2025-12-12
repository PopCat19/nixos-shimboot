# Theme Window Rules Module
#
# Purpose: Configure centralized application-specific opacity and window rules
# Dependencies: theme_config/visual.nix
# Related: theme.nix
#
# This module:
# - Defines opacity categories for different application types
# - Provides centralized window rules for consistent application behavior
# - Manages floating window configurations
# - Exports window rules for Hyprland integration
{
  lib,
  pkgs,
  config,
  inputs,
  ...
}: let
  inherit (import ./visual.nix {inherit pkgs config inputs;}) theme;
in {
  # Define options for window rules
  options = {
    theme.opacityCategories = lib.mkOption {
      type = lib.types.attrs;
      default = {
        standard = {
          regular = 0.85;
          inactive = 0.85;
        };
        utilities = {
          regular = 0.85;
          inactive = 0.75;
        };
        media = {
          regular = 0.75;
          inactive = 0.75;
        };
        special = {
          clapper = 0.90;
          steam_game = "0.88 0.76";
        };
      };
      description = "Application opacity categories";
    };

    theme.applicationOpacity = lib.mkOption {
      type = lib.types.attrs;
      default = {
        standard = [
          "code-oss"
          "[Cc]ode"
          "code-url-handler"
          "code-insiders-url-handler"
          "kitty"
          "org.kde.dolphin"
          "org.kde.ark"
          "nemo"
          "nautilus"
          "nwg-look"
          "qt5ct"
          "qt6ct"
          "kvantummanager"
          "com.github.tchx84.Flatseal"
          "hu.kramo.Cartridges"
          "com.obsproject.Studio"
          "gnome-boxes"
          "vesktop"
          "discord"
          "WebCord"
          "ArmCord"
          "app.drey.Warp"
          "net.davidotek.pupgui2"
          "yad"
          "Signal"
          "io.github.alainm23.planify"
          "io.gitlab.theevilskeleton.Upscaler"
          "com.github.unrud.VideoDownloader"
          "io.gitlab.adhami3310.Impression"
          "io.missioncenter.MissionCenter"
          "io.github.flattool.Warehouse"
        ];
        utilities = [
          "org.pulseaudio.pavucontrol"
          "blueman-manager"
          "nm-applet"
          "nm-connection-editor"
          "org.kde.polkit-kde-authentication-agent-1"
          "polkit-gnome-authentication-agent-1"
          "org.freedesktop.impl.portal.desktop.gtk"
          "org.freedesktop.impl.portal.desktop.hyprland"
        ];
        media = [
          "[Ss]team"
          "steamwebhelper"
          "^([Ss]potify)"
          "initialTitle:^(Spotify Free)$"
          "initialTitle:^(Spotify Premium)$"
        ];
        special = [
          { class = "com.github.rafostar.Clapper"; opacity = 0.90; }
          { 
            class = "steam_app_1920960"; 
            title = "MainWindow"; 
            xwayland = true; 
            opacity = "0.88 0.76"; 
          }
        ];
      };
      description = "Application class mappings to opacity categories";
    };
  };

  config = {
    theme.opacityCategories = {
      standard = {
        regular = 0.85;
        inactive = 0.85;
      };
      utilities = {
        regular = 0.85;
        inactive = 0.75;
      };
      media = {
        regular = 0.75;
        inactive = 0.75;
      };
      special = {
        clapper = 0.90;
        steam_game = "0.88 0.76";
      };
    };

    theme.applicationOpacity = {
      standard = [
        "code-oss"
        "[Cc]ode"
        "code-url-handler"
        "code-insiders-url-handler"
        "kitty"
        "org.kde.dolphin"
        "org.kde.ark"
        "nemo"
        "nautilus"
        "nwg-look"
        "qt5ct"
        "qt6ct"
        "kvantummanager"
        "com.github.tchx84.Flatseal"
        "hu.kramo.Cartridges"
        "com.obsproject.Studio"
        "gnome-boxes"
        "vesktop"
        "discord"
        "WebCord"
        "ArmCord"
        "app.drey.Warp"
        "net.davidotek.pupgui2"
        "yad"
        "Signal"
        "io.github.alainm23.planify"
        "io.gitlab.theevilskeleton.Upscaler"
        "com.github.unrud.VideoDownloader"
        "io.gitlab.adhami3310.Impression"
        "io.missioncenter.MissionCenter"
        "io.github.flattool.Warehouse"
      ];
      utilities = [
        "org.pulseaudio.pavucontrol"
        "blueman-manager"
        "nm-applet"
        "nm-connection-editor"
        "org.kde.polkit-kde-authentication-agent-1"
        "polkit-gnome-authentication-agent-1"
        "org.freedesktop.impl.portal.desktop.gtk"
        "org.freedesktop.impl.portal.desktop.hyprland"
      ];
      media = [
        "[Ss]team"
        "steamwebhelper"
        "^([Ss]potify)"
        "initialTitle:^(Spotify Free)$"
        "initialTitle:^(Spotify Premium)$"
      ];
      special = [
        { class = "com.github.rafostar.Clapper"; opacity = 0.90; }
        { 
          class = "steam_app_1920960"; 
          title = "MainWindow"; 
          xwayland = true; 
          opacity = "0.88 0.76"; 
        }
      ];
    };
  };
}