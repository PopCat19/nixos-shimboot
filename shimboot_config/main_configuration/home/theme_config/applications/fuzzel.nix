# Fuzzel Launcher Theme Module
#
# Purpose: Configure Fuzzel application launcher with Rose Pine theme
# Dependencies: userConfig, theme_config/theme_fonts.nix, theme_config/colors.nix, theme_config/visual.nix
# Related: fuzzel.nix
#
# This module:
# - Configures Fuzzel with Rose Pine color scheme
# - Applies theme fonts and sizing
# - Sets up keyboard shortcuts and appearance
{
  lib,
  pkgs,
  config,
  inputs,
  userConfig,
  ...
}: let
  inherit (import ../colors.nix {inherit pkgs config inputs;}) getColor getColorWithOpacity;
  inherit (import ../visual.nix {inherit pkgs config inputs;}) alpha radius borders helpers;
  inherit (import ../theme_fonts.nix {inherit pkgs config inputs;}) fonts;
in {
  programs.fuzzel.settings = {
    main = {
      layer = "overlay";
      placeholder = "Search applications...";
      width = 50;
      lines = 12;
      horizontal-pad = 20;
      vertical-pad = 12;
      inner-pad = 8;
      image-size-ratio = 0.8;
      show-actions = true;
      terminal = userConfig.defaultApps.terminal.command;
      filter-desktop = true;
      icon-theme = "Papirus-Dark";
      icons-enabled = true;
      password-character = "*";
      list-executables-in-path = false;
      font = "${fonts.main}:size=${toString fonts.sizes.fuzzel}";
    };
    colors = {
      background = getColorWithOpacity "background" alpha.high;
      text = getColorWithOpacity "text" alpha.full;
      match = getColorWithOpacity "accent-active" alpha.full;
      selection = getColorWithOpacity "selected" alpha.full;
      selection-text = getColorWithOpacity "text" alpha.full;
      selection-match = getColorWithOpacity "accent-hover" alpha.full;
      border = getColorWithOpacity "accent" alpha.full;
      placeholder = getColorWithOpacity "text-secondary" alpha.full;
    };
    border = {
      radius = radius.medium;
      width = borders.width.small;
    };
    key-bindings = {
      cancel = "Escape Control+c Control+g";
      execute = "Return KP_Enter Control+m";
      execute-or-next = "Tab";
      cursor-left = "Left Control+b";
      cursor-left-word = "Control+Left Mod1+b";
      cursor-right = "Right Control+f";
      cursor-right-word = "Control+Right Mod1+f";
      cursor-home = "Home Control+a";
      cursor-end = "End Control+e";
      delete-prev = "BackSpace Control+h";
      delete-prev-word = "Mod1+BackSpace Control+w";
      delete-next = "Delete Control+d";
      delete-next-word = "Mod1+d";
      prev = "Up Control+p";
      next = "Down Control+n";
      first = "Control+Home";
      last = "Control+End";
    };
  };
}