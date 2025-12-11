# Theme Module
#
# Purpose: Configure Rose Pine theme across GTK, Qt, and desktop environments
# Dependencies: lib/theme.nix, rose-pine packages
# Related: environment.nix, qt-gtk-config.nix
#
# This module:
# - Sets up Rose Pine color scheme for GTK and Qt applications
# - Configures cursor, icon, and window themes
# - Manages Kvantum theme engine settings
{
  lib,
  pkgs,
  config,
  inputs,
  userConfig,
  ...
}: let
  inherit (import ./lib/theme.nix {inherit lib pkgs config inputs;}) defaultVariant fonts commonPackages mkSessionVariables;

  selectedVariant = defaultVariant;

  iconTheme = "Papirus-Dark";

  cursorSize = 24;

  cursorPackage = inputs.rose-pine-hyprcursor.packages.${pkgs.system}.default;
  kvantumPkg = pkgs.kdePackages.qtstyleplugin-kvantum;
  rosePineKvantum = pkgs.rose-pine-kvantum;
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

  xdg.configFile."Kvantum/rose-pine-rose".source = "${rosePineKvantum}/share/Kvantum/rose-pine-rose";
  xdg.configFile."Kvantum/rose-pine-moon".source = "${rosePineKvantum}/share/Kvantum/rose-pine-moon";

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

  home.file.".config/qt5ct/qt5ct.conf" = {
    text = ''
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
  };

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
