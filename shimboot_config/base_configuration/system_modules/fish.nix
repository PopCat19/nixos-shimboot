{lib, ...}: {
  # System programs configuration
  # Fish and Starship are configured in home_modules for user-specific settings.
  # This module provides system-wide Fish configuration including the greeting function.

  programs = {
    # Shell configuration
    fish = {
      enable = lib.mkDefault true;

      # Load the custom greeting function from external file
      interactiveShellInit = lib.mkDefault ''
        # Load custom greeting function
        ${let
          content = builtins.readFile ./fish_functions/fish-greeting.fish;
          lines = lib.splitString "\n" content;
        in
          lib.concatStringsSep "\n" (lib.sublist 1 (lib.length lines - 2) lines)}
      '';
    };

    # Starship with defaults that can be overridden
    starship = {
      enable = lib.mkDefault true;
      settings = lib.mkDefault {
        # Basic configuration that can be overridden by main configuration
        format = "$directory$git_branch$git_status$character";
        character = {
          success_symbol = "[➜](bold green)";
          error_symbol = "[➜](bold red)";
        };
      };
    };
  };
}
