# Theme Files Module
#
# Purpose: Configure theme-related configuration files
# Dependencies: theme colors
# Related: theme.nix
#
# This module:
# - Creates Kvantum configuration files
# - Sets up Qt5CT configuration
# - Manages KDE global settings
{
  lib,
  pkgs,
  config,
  inputs,
  ...
}: let
  # Define default variant directly since colors.nix is now a module
  defaultVariant = {
    name = "rose-pine-main";
    gtkThemeName = "Rose-Pine-Main-BL";
    iconTheme = "Rose-Pine";
    cursorTheme = "rose-pine-hyprcursor";
    kvantumTheme = "rose-pine-rose";
  };
  
  iconTheme = "Papirus-Dark";
in {
  home.file = {
    ".config/Kvantum/kvantum.kvconfig".text = ''
      [General]
      theme=${defaultVariant.kvantumTheme}
    '';

    ".config/qt5ct/qt5ct.conf".text = ''
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

    ".config/kdeglobals".text = ''
      [Icons]
      Theme=${iconTheme}
    '';
  };
}