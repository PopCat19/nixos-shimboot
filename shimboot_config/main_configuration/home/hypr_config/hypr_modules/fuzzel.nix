# Fuzzel Launcher Module
#
# Purpose: Configure Fuzzel application launcher with Rose Pine theme
# Dependencies: userConfig, theme fonts
# Related: keybinds.nix, ../../home_modules/lib/theme.nix
#
# This module:
# - Enables Fuzzel with overlay display mode
# - Configures Rose Pine color scheme
# - Sets up keyboard shortcuts and appearance
# - Applies theme font configuration
{
  lib,
  pkgs,
  config,
  inputs,
  userConfig,
  ...
}: let
  fonts = (import ../../home_modules/lib/theme.nix {inherit lib pkgs config inputs;}).fonts;
in {
  programs.fuzzel = {
    enable = true;
    settings = {
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
        background = "191724f0";
        text = "e0def4ff";
        match = "eb6f92ff";
        selection = "403d52ff";
        selection-text = "e0def4ff";
        selection-match = "f6c177ff";
        border = "ebbcbaff";
        placeholder = "908caaff";
      };
      border = {
        radius = 12;
        width = 2;
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
  };
}
