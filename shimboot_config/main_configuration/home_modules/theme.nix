{ lib
, pkgs
, config
, inputs
, userConfig
, ...
}: let
  inherit (import ./lib/theme.nix { inherit lib pkgs config inputs; }) defaultVariant fonts commonPackages mkSessionVariables;

  # Selected variant (easy to switch here)
  selectedVariant = defaultVariant;  # Change to variants.moon for darker theme

  iconTheme = "Papirus-Dark";  # Centralized if needed
  cursorSize = 24;

  cursorPackage = inputs.rose-pine-hyprcursor.packages.${pkgs.system}.default;
  kvantumPkg = pkgs.kdePackages.qtstyleplugin-kvantum;
  rosePineKvantum = pkgs.rose-pine-kvantum;
  rosePineGtk =
    if builtins.hasAttr "rose-pine-gtk-theme-full" pkgs then pkgs.rose-pine-gtk-theme-full
    else if builtins.hasAttr "rose-pine-gtk-theme" pkgs then pkgs.rose-pine-gtk-theme
    else null;
in {
  home.sessionVariables = mkSessionVariables selectedVariant fonts.sizes // {
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
      // lib.optionalAttrs (rosePineGtk != null) { package = rosePineGtk; };
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

  # Ensure Kvantum can find Rosé Pine themes from our package
  # Kvantum searches ~/.config/Kvantum and XDG data dirs (share/Kvantum)
  # These symlinks guarantee availability regardless of XDG_DATA_DIRS.
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

  # Ensure Qt5 apps also use Kvantum style and Papirus icons
  # KDE reads ~/.config/kdeglobals for the icon theme.
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

  # Ensure KDE Frameworks apps (Dolphin, Gwenview, Okular, etc.) use Papirus icons
  # KDE reads ~/.config/kdeglobals for the icon theme.
  home.file.".config/kdeglobals".text = ''
    [Icons]
    Theme=${iconTheme}
  '';

  # Use centralized package list from lib/theme.nix and add module-specific extras
  # Avoid duplicating cursorPackage (already included in commonPackages)
  home.packages = with pkgs; commonPackages ++ [
    rose-pine-kvantum
  ];
}
