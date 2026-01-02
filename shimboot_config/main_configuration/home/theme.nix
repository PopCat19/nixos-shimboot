# Theme Module
#
# Purpose: Configure Rose Pine theme across GTK, Qt, and desktop environments
# Dependencies: rose-pine packages, inputs
# Related: environment.nix
#
# This module:
# - Sets up Rose Pine color scheme for GTK and Qt applications
# - Configures cursor, icon, and window themes
# - Manages Kvantum theme engine settings
{
  lib,
  pkgs,
  inputs,
  ...
}: let
  system = "x86_64-linux";
  rosePineColors = {
    base = "191724";
    surface = "1f1d2e";
    overlay = "26233a";
    muted = "6e6a86";
    subtle = "908caa";
    text = "e0def4";
    love = "eb6f92";
    gold = "f6c177";
    rose = "ebbcba";
    pine = "31748f";
    foam = "9ccfd8";
    iris = "c4a7e7";
    highlightLow = "21202e";
    highlightMed = "403d52";
    highlightHigh = "524f67";
  };

  variants = {
    main = {
      gtkThemeName = "Rose-Pine-Main-BL";
      iconTheme = "Rose-Pine";
      cursorTheme = "rose-pine-hyprcursor";
      kvantumTheme = "rose-pine-rose";
      colors = rosePineColors;
    };
  };

  defaultVariant = variants.main;

  fonts = {
    main = "Rounded Mplus 1c Medium";
    mono = "JetBrainsMono Nerd Font";
    sizes = {
      fuzzel = 10;
      kitty = 10;
      gtk = 10;
    };
  };

  commonPackages = with pkgs; [
    inputs.rose-pine-hyprcursor.packages.${system}.default
    rose-pine-gtk-theme-full
    kdePackages.qtstyleplugin-kvantum
    papirus-icon-theme
    nwg-look
    libsForQt5.qt5ct
    qt6Packages.qt6ct
    polkit_gnome
    gsettings-desktop-schemas
  ];

  mkSessionVariables = variant: _sizes: {
    QT_STYLE_OVERRIDE = "kvantum";
    QT_QPA_PLATFORM = "wayland;xcb";
    GTK_THEME = variant.gtkThemeName;
    GDK_BACKEND = "wayland,x11,*";
    XCURSOR_THEME = variant.cursorTheme;
    QT_QUICK_CONTROLS_STYLE = "Kvantum";
    QT_QUICK_CONTROLS_MATERIAL_THEME = "Dark";
  };

  selectedVariant = defaultVariant;

  iconTheme = "Papirus-Dark";

  cursorSize = 24;

  cursorPackage = inputs.rose-pine-hyprcursor.packages.${pkgs.system}.default;
  kvantumPkg = pkgs.kdePackages.qtstyleplugin-kvantum;
  rosePineGtk =
    if builtins.hasAttr "rose-pine-gtk-theme-full" pkgs
    then pkgs.rose-pine-gtk-theme-full
    else if builtins.hasAttr "rose-pine-gtk-theme" pkgs
    then pkgs.rose-pine-gtk-theme
    else null;
in {
  home.sessionVariables =
    mkSessionVariables selectedVariant fonts.sizes
    // {
      XCURSOR_SIZE = builtins.toString cursorSize;
    };

  gtk = {
    enable = true;
    cursorTheme = {
      name = selectedVariant.cursorTheme or "rose-pine-hyprcursor";
      size = cursorSize;
      package = cursorPackage;
    };
    theme =
      {
        name = selectedVariant.gtkThemeName;
      }
      // lib.optionalAttrs (rosePineGtk != null) {package = rosePineGtk;};
    iconTheme = {
      name = iconTheme;
      package = pkgs.papirus-icon-theme;
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
  };

  qt = {
    enable = true;
    style = {
      name = "kvantum";
      package = kvantumPkg;
    };
  };

  home.file.".config/Kvantum/kvantum.kvconfig".text = ''
    [General]
    theme=${selectedVariant.kvantumTheme}
  '';

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      cursor-theme = selectedVariant.cursorTheme;
      cursor-size = cursorSize;
      gtk-theme = selectedVariant.gtkThemeName;
      icon-theme = iconTheme;
      color-scheme = "prefer-dark";
    };

    "org/gnome/desktop/wm/preferences" = {
      theme = selectedVariant.gtkThemeName;
    };
  };

  home.file.".config/qt5ct/qt5ct.conf".text = ''
    [Appearance]
    color_scheme_path=
    custom_palette=false
    icon_theme=${iconTheme}
    style=kvantum

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
  '';

  home.file.".config/kdeglobals".text = ''
    [Icons]
    Theme=${iconTheme}
  '';

  home.packages = with pkgs;
    commonPackages
    ++ [
      rose-pine-kvantum
    ];
}
