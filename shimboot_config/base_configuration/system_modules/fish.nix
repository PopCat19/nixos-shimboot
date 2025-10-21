{
  lib,
  ...
}: {
  # System programs configuration
  # Fish and Starship are configured in home_modules for user-specific settings.
  # This module provides system-wide Fish configuration including the greeting function.

  programs = {
    # Shell configuration
    fish = {
      enable = true;
      
      # Load the custom greeting function from external file
      interactiveShellInit = ''
        # Load custom greeting function
        ${let
          content = builtins.readFile ./fish_functions/fish-greeting.fish;
          lines = lib.splitString "\n" content;
        in
          lib.concatStringsSep "\n" (lib.sublist 1 (lib.length lines - 2) lines)}
      '';
    };
  };
}
