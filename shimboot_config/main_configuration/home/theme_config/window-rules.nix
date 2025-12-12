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
  pkgs,
  config,
  inputs,
  ...
}: let
  inherit (import ./visual.nix {inherit pkgs config inputs;}) opacity;
in {
  # Application opacity categories
  opacityCategories = {
    # Standard applications (85% opacity)
    standard = {
      regular = 0.85;
      inactive = 0.85;
    };
    
    # Utility/Dialog applications (75% opacity for inactive)
    utilities = {
      regular = 0.85;
      inactive = 0.75;
    };
    
    # Media/Entertainment applications (75% opacity)
    media = {
      regular = 0.75;
      inactive = 0.75;
    };
    
    # Special cases with custom opacity
    special = {
      clapper = 0.90;
      steam_game = "0.88 0.76";  # Special case for specific Steam game
    };
  };

  # Application class mappings to opacity categories
  applicationOpacity = {
    # Standard applications (0.85 0.85)
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
    
    # Utility applications (0.85 0.75)
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
    
    # Media applications (0.75 0.75)
    media = [
      "[Ss]team"
      "steamwebhelper"
      "^([Ss]potify)"
      "initialTitle:^(Spotify Free)$"
      "initialTitle:^(Spotify Premium)$"
    ];
    
    # Special applications
    special = [
      # Clapper at 0.90 0.90
      { class = "com.github.rafostar.Clapper"; opacity = opacityCategories.special.clapper; }
      
      # Steam game with special opacity
      { 
        class = "steam_app_1920960"; 
        title = "MainWindow"; 
        xwayland = true; 
        opacity = opacityCategories.special.steam_game; 
      }
    ];
  };

  # Floating window rules for better UX
  floatingRules = [
    # File manager dialogs
    "float,class:^(org.kde.dolphin)$,title:^(Progress Dialog — Dolphin)$"
    "float,class:^(org.kde.dolphin)$,title:^(Copying — Dolphin)$"
    
    # System dialogs
    "float,title:^(About Mozilla Firefox)$"
    "float,class:^(firefox)$,title:^(Picture-in-Picture)$"
    "float,class:^(firefox)$,title:^(Library)$"
    
    # Terminal utilities
    "float,class:^(kitty)$,title:^(top)$"
    "float,class:^(kitty)$,title:^(btop)$"
    "float,class:^(kitty)$,title:^(htop)$"
    
    # Media players
    "float,class:^(vlc)$"
    "float,class:^(mpv)$"
    
    # Configuration tools
    "float,class:^(kvantummanager)$"
    "float,class:^(qt5ct)$"
    "float,class:^(qt6ct)$"
    "float,class:^(nwg-look)$"
    "float,class:^(org.kde.ark)$"
    
    # System utilities
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
    
    # File dialogs
    "float,title:^(Open)$"
    "float,title:^(Choose Files)$"
    "float,title:^(Save As)$"
    "float,title:^(Confirm to replace files)$"
    "float,title:^(File Operation Progress)$"
  ];

  # General window rules
  generalRules = [
    "suppressevent maximize, class:.*"
    "nofocus,class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0"
    "minsize 1024 600,class:^(org.pulseaudio.pavucontrol)$"
  ];

  # Convert application opacity lists to Hyprland window rules format
  mkOpacityRules = category: opacityValues: map (class: "opacity ${toString opacityValues.regular} ${toString opacityValues.inactive},class:^(${class})$") category;
  
  # Generate all window rules
  windowRules = 
    generalRules
    ++ (mkOpacityRules applicationOpacity.standard opacityCategories.standard)
    ++ (mkOpacityRules applicationOpacity.utilities opacityCategories.utilities)
    ++ (mkOpacityRules applicationOpacity.media opacityCategories.media)
    ++ (map (app: 
      if app ? opacity 
      then "opacity ${toString app.opacity},class:^(${app.class})$"
      else "opacity ${toString opacityCategories.standard.regular} ${toString opacityCategories.standard.inactive},class:^(${app.class})$"
    ) applicationOpacity.special)
    ++ floatingRules;

in {
  inherit opacityCategories applicationOpacity floatingRules generalRules windowRules;
}