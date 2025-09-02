{ pkgs, config, system, lib, inputs, ... }:

let
  theme = {
    gtkThemeName = "Rose-Pine-Main-BL";
    iconTheme = "Papirus-Dark";
    cursorTheme = "rose-pine-hyprcursor";
    cursorSize = 24;
    kvantumTheme = "rose-pine-rose";
    kdeColorSchemeName = "Rose-Pine-Main-BL";
    fontMain = "Rounded Mplus 1c Medium";
    fontMono = "JetBrainsMono Nerd Font";
    fuzzelFontSize = 14;
    kittyFontSize = 11;
    gtkFontSize = 11;
  };

  cursorPackage = inputs.rose-pine-hyprcursor.packages.${system}.default;
  kvantumPkg = pkgs.kdePackages.qtstyleplugin-kvantum;
  rosePineKvantum = pkgs.rose-pine-kvantum;
  rosePineGtk = pkgs.rose-pine-gtk-theme-full;

  gtkCss = ''
    * {
      font-family: "${theme.fontMain}";
    }
  '';
in
{
  home.sessionVariables = {
    QT_STYLE_OVERRIDE = "kvantum";
    QT_QPA_PLATFORM = "wayland;xcb";
    GTK_THEME = theme.gtkThemeName;
    GDK_BACKEND = "wayland,x11,*";
    XCURSOR_THEME = theme.cursorTheme;
    XCURSOR_SIZE = builtins.toString theme.cursorSize;
    QT_QUICK_CONTROLS_STYLE = "Kvantum";
    QT_QUICK_CONTROLS_MATERIAL_THEME = "Dark";
  };

  gtk = {
    enable = true;
    cursorTheme = {
      name = theme.cursorTheme;
      size = theme.cursorSize;
      package = cursorPackage;
    };
    theme = {
      name = theme.gtkThemeName;
      package = rosePineGtk;
    };
    iconTheme = {
      name = theme.iconTheme;
      package = pkgs.papirus-icon-theme;
    };
    font = {
      name = theme.fontMain;
      size = theme.gtkFontSize;
    };
    gtk3.extraConfig = {
      gtk-decoration-layout = "appmenu:minimize,maximize,close";
      gtk-enable-animations = true;
      gtk-primary-button-warps-slider = false;
    };
    gtk4.extraConfig = {
      gtk-decoration-layout = "appmenu:minimize,maximize,close";
      gtk-enable-animations = true;
      gtk-primary-button-warps-slider = false;
    };
    gtk3.extraCss = gtkCss;
    gtk4.extraCss = gtkCss;
  };

  qt = {
    enable = true;
    style = {
      name = "kvantum";
      package = kvantumPkg;
    };
  };

  home.file.".config/Kvantum/RosePine".source = "${rosePineKvantum}/share/Kvantum/themes/${theme.kvantumTheme}";

  xdg.configFile."Kvantum/kvantum.kvconfig".text = ''
    [General]
    theme=${theme.kvantumTheme}

    [Applications]
    # KDE Applications
    dolphin=${theme.kvantumTheme}
    dolphin.exe=${theme.kvantumTheme}
    org.kde.dolphin=${theme.kvantumTheme}
    ark=${theme.kvantumTheme}
    gwenview=${theme.kvantumTheme}
    systemsettings=${theme.kvantumTheme}
    kate=${theme.kvantumTheme}
    kwrite=${theme.kvantumTheme}
    okular=${theme.kvantumTheme}
    konsole=${theme.kvantumTheme}
    kcalc=${theme.kvantumTheme}
    kcharselect=${theme.kvantumTheme}
    kcolorchooser=${theme.kvantumTheme}
    kdf=${theme.kvantumTheme}
    keditbookmarks=${theme.kvantumTheme}
    kfind=${theme.kvantumTheme}
    kgpg=${theme.kvantumTheme}
    kleopatra=${theme.kvantumTheme}
    klipper=${theme.kvantumTheme}
    kmag=${theme.kvantumTheme}
    kmousetool=${theme.kvantumTheme}
    kmouth=${theme.kvantumTheme}
    knotes=${theme.kvantumTheme}
    kruler=${theme.kvantumTheme}
    ksysguard=${theme.kvantumTheme}
    ktimer=${theme.kvantumTheme}
    kwalletmanager=${theme.kvantumTheme}
    plasma-discover=${theme.kvantumTheme}
    spectacle=${theme.kvantumTheme}

    # Qt Applications
    qtcreator=${theme.kvantumTheme}
    qterminal=${theme.kvantumTheme}
    featherpad=${theme.kvantumTheme}
    lxqt-config=${theme.kvantumTheme}

    # Generic fallbacks
    *=${theme.kvantumTheme}
  '';

  xdg.configFile."Kvantum/themes/${theme.kvantumTheme}.kvconfig".text = ''
    [General]
    author=rose-pine
    comment=Rose Pine theme for Kvantum
    name=${theme.kvantumTheme}

    [Hacks]
    align_menuitem_arrows=0
    blur_translucent=0
    centered_forms=0
    combo_menu=0
    compositing=0
    force_size_grip=0
    gtk_menubar_hack=0
    iconless_menu=0
    iconless_pushbutton=0
    kde_globals_following=1
    left_tabs_on_bottom=0
    lock_kde_globals=0
    menu_blur=0
    menu_separator_height=0
    merge_menubar_with_toolbar=0
    no_selection_inactive=0
    opaque_resize_grip=0
    respect_darkness=1
    scroll_jump_workaround=0
    scroll_minimal=0
    scrollbar_in_view=0
    submenu_overlap=0
    tint_on_mouseover=0
    transparent_dolphin_view=1
    transparent_ktitle_label=0
    transparent_menutitle=0
    unify_spin_buttons=0
  '';

  

  xdg.configFile."kdeglobals".text = ''
    [General]
    ColorScheme=${theme.kdeColorSchemeName}
    Name=${theme.kdeColorSchemeName}
    shadeSortColumn=true

    [Icons]
    Theme=${theme.iconTheme}

    [KDE]
    contrast=4
    widgetStyle=kvantum
  '';

  xdg.dataFile."color-schemes/${theme.kdeColorSchemeName}.colors".text = ''
    [ColorScheme]
    Name=${theme.kdeColorSchemeName}
    Description=Rose Pine color scheme integrated with Kvantum

    [General]
    shadeSortColumn=true

    [KDE]
    contrast=4

    [Colors:View]
    BackgroundNormal=25,23,36
    BackgroundAlternate=31,29,46
    DecorationFocus=156,207,216
    DecorationHover=156,207,216
    ForegroundNormal=224,222,244
    ForegroundActive=224,222,244
    ForegroundInactive=144,140,170
    ForegroundLink=156,207,216
    ForegroundVisited=196,167,231
    ForegroundNegative=235,111,146
    ForegroundNeutral=246,193,119
    ForegroundPositive=156,207,216

    [Colors:Window]
    BackgroundNormal=25,23,36
    BackgroundAlternate=31,29,46
    DecorationFocus=156,207,216
    DecorationHover=156,207,216
    ForegroundNormal=224,222,244
    ForegroundActive=224,222,244
    ForegroundInactive=144,140,170
    ForegroundLink=156,207,216
    ForegroundVisited=196,167,231
    ForegroundNegative=235,111,146
    ForegroundNeutral=246,193,119
    ForegroundPositive=156,207,216

    [Colors:Button]
    BackgroundNormal=49,46,77
    BackgroundAlternate=49,46,77
    DecorationFocus=156,207,216
    DecorationHover=156,207,216
    ForegroundNormal=224,222,244
    ForegroundActive=224,222,244
    ForegroundInactive=144,140,170
    ForegroundLink=156,207,216
    ForegroundVisited=196,167,231
    ForegroundNegative=235,111,146
    ForegroundNeutral=246,193,119
    ForegroundPositive=156,207,216

    [Colors:Selection]
    BackgroundNormal=64,61,82
    BackgroundAlternate=82,79,103
    DecorationFocus=156,207,216
    DecorationHover=156,207,216
    ForegroundNormal=224,222,244
    ForegroundActive=224,222,244
    ForegroundInactive=144,140,170
    ForegroundLink=156,207,216
    ForegroundVisited=196,167,231
    ForegroundNegative=235,111,146
    ForegroundNeutral=246,193,119
    ForegroundPositive=156,207,216

    [Colors:Tooltip]
    BackgroundNormal=25,23,36
    BackgroundAlternate=25,23,36
    DecorationFocus=156,207,216
    DecorationHover=156,207,216
    ForegroundNormal=224,222,244
    ForegroundActive=224,222,244
    ForegroundInactive=144,140,170
    ForegroundLink=156,207,216
    ForegroundVisited=196,167,231
    ForegroundNegative=235,111,146
    ForegroundNeutral=246,193,119
    ForegroundPositive=156,207,216

    [Colors:Complementary]
    BackgroundNormal=38,35,58
    BackgroundAlternate=49,46,77
    DecorationFocus=235,188,186
    DecorationHover=235,188,186
    ForegroundNormal=224,222,244
    ForegroundActive=224,222,244
    ForegroundInactive=110,106,134
    ForegroundLink=156,207,216
    ForegroundVisited=196,167,231
    ForegroundNegative=235,111,146
    ForegroundNeutral=246,193,119
    ForegroundPositive=156,207,216
  '';

  home.file.".config/qt6ct/qt6ct.conf" = {
    text = ''
      [Appearance]
      color_scheme_path=
      custom_palette=false
      icon_theme=${theme.iconTheme}
      standard_dialogs=default
      style=kvantum

      [Fonts]
      fixed="${theme.fontMono},11,-1,5,50,0,0,0,0,0"
      general="${theme.fontMain},${builtins.toString theme.gtkFontSize},-1,5,50,0,0,0,0,0"

      [Interface]
      activate_item_on_single_click=1
      buttonbox_layout=0
      cursor_flash_time=1000
      dialog_buttons_have_icons=1
      double_click_interval=400
      gui_effects=@Invalid()
      keyboard_scheme=2
      menus_have_icons=true
      show_shortcuts_in_context_menus=true
      stylesheets=@Invalid()
      toolbutton_style=4
      underline_shortcut=1
      wheel_scroll_lines=3

      [SettingsWindow]
      geometry=@ByteArray(\x1\xd9\xd0\xcb\0\x3\0\0\0\0\0\0\0\0\0\0\0\0\x2\x7f\0\0\x1\xdf\0\0\0\0\0\0\0\0\0\0\x2\x7f\0\0\x1\xdf\0\0\0\0\x2\0\0\0\n\0\0\0\0\0\0\0\0\0\0\0\x2\x7f\0\0\x1\xdf)
    '';
  };

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      cursor-theme = theme.cursorTheme;
      cursor-size = theme.cursorSize;
      gtk-theme = theme.gtkThemeName;
      icon-theme = theme.iconTheme;
      font-name = "${theme.fontMain} ${builtins.toString theme.gtkFontSize}";
      document-font-name = "${theme.fontMain} ${builtins.toString theme.gtkFontSize}";
      monospace-font-name = "${theme.fontMono} ${builtins.toString theme.kittyFontSize}";
      color-scheme = "prefer-dark";
    };

   "org/gnome/desktop/wm/preferences" = {
      theme = theme.gtkThemeName;
    };

    "org/gnome/desktop/thumbnailers" = {
      disable-all = false;
    };

    "org/gnome/nautilus/preferences" = {
      show-image-thumbnails = "always";
      thumbnail-limit = 10;
      show-directory-item-counts = "always";
    };

    "org/nemo/preferences" = {
      show-image-thumbnails = true;
      thumbnail-limit = 10;
      show-thumbnails = true;
    };

    "org/gnome/desktop/privacy" = {
      remember-recent-files = true;
      recent-files-max-age = 30;
    };
  };

  systemd.user.services.polkit-gnome-authentication-agent-1 = {
    Unit = {
      Description = "polkit-gnome-authentication-agent-1";
      Wants = [ "graphical-session.target" ];
      WantedBy = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };

  programs.kitty.font = {
    name = theme.fontMono;
    size = theme.kittyFontSize;
  };

  programs.fuzzel.settings.main.font = "${theme.fontMain}:size=${builtins.toString theme.fuzzelFontSize}";

  home.file.".config/fontconfig/fonts.conf".text = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
    <fontconfig>
      <alias>
        <family>sans-serif</family>
        <prefer>
          <family>${theme.fontMain}</family>
        </prefer>
      </alias>
      <alias>
        <family>${theme.fontMain}</family>
        <default>
          <family>sans-serif</family>
        </default>
      </alias>
    </fontconfig>
  '';

  home.packages = with pkgs; [
    google-fonts
    vim
    firefox
    htop
    neofetch
    nerd-fonts.jetbrains-mono
    nerd-fonts.caskaydia-cove
    nerd-fonts.fantasque-sans-mono
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-emoji
    font-awesome
    nwg-look
    dconf-editor
    libsForQt5.qt5ct
    qt6ct
    themechanger
    kdePackages.qtstyleplugin-kvantum
    libsForQt5.qtstyleplugin-kvantum
    rose-pine-kvantum
    rose-pine-gtk-theme-full
    cursorPackage
    catppuccin-gtk
    catppuccin-cursors
    papirus-icon-theme
    adwaita-icon-theme
    polkit_gnome
    gsettings-desktop-schemas
  ];
}
