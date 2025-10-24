# Fish Shell Configuration Module
#
# Purpose: Configure Fish shell system-wide settings
# Dependencies: fish, starship
# Related: fish-functions.nix, packages.nix
#
# This module:
# - Enables Fish as the default shell
# - Loads custom greeting function from external file
# - Configures Starship prompt with basic defaults

{lib, ...}: {
  programs = {
    fish = {
      enable = lib.mkDefault true;

      interactiveShellInit = lib.mkDefault ''
        ${let
          content = builtins.readFile ./fish_functions/fish-greeting.fish;
          lines = lib.splitString "\n" content;
        in
          lib.concatStringsSep "\n" (lib.sublist 1 (lib.length lines - 2) lines)}
      '';
    };

    starship = {
      enable = lib.mkDefault true;
      settings = lib.mkDefault {
        format = "$directory$git_branch$git_status$character";
        character = {
          success_symbol = "[➜](bold green)";
          error_symbol = "[➜](bold red)";
        };
      };
    };
  };
}
