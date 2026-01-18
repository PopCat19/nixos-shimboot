# Fish Shell Configuration Module
#
# Purpose: Configure Fish shell with functions, abbreviations, and Starship prompt
# Dependencies: fish, starship, eza
# Related: packages.nix, users.nix
#
# This module:
# - Enables Fish as the default shell
# - Sets up environment variables for NixOS configuration
# - Loads custom Fish functions from external files
# - Defines shell abbreviations for common commands
# - Configures Starship prompt
{
  lib,
  pkgs,
  ...
}:
{
  programs.fish.enable = lib.mkDefault true;
  programs.starship.enable = lib.mkDefault true;

  programs.fish.interactiveShellInit = ''
    # Make system-wide functions visible
    if not contains /etc/fish/functions $fish_function_path
        set -g fish_function_path /etc/fish/functions $fish_function_path
    end

    # Abbreviations for common NixOS commands
    abbr -a nrb nixos-rebuild-basic
    abbr -a flup nixos-flake-update
    abbr -a cdn 'cd $NIXOS_CONFIG_DIR'
  '';

  environment.etc = {
    # Fish-specific configuration
    "fish/conf.d/00-shimboot.fish".text = ''
      if status is-interactive
        starship init fish | source
      end
    '';

    # Function definitions
    "fish/functions/fish_greeting.fish".text = builtins.readFile ./fish_functions/fish-greeting.fish;

    "fish/functions/nixos-rebuild-basic.fish".text =
      builtins.readFile ./fish_functions/nixos-rebuild-basic.fish;

    "fish/functions/nixos-flake-update.fish".text =
      builtins.readFile ./fish_functions/nixos-flake-update.fish;

    "fish/functions/fix-fish-history.fish".text =
      builtins.readFile ./fish_functions/fix-fish-history.fish;

    "fish/functions/list-fish-helpers.fish".text =
      builtins.readFile ./fish_functions/list-fish-helpers.fish;

    "fish/functions/cnup.fish".text = builtins.readFile ./fish_functions/cnup.fish;
    "fish/functions/lsa.fish".text = builtins.readFile ./fish_functions/lsa.fish;

    # Helper functions from helpers directory
    "fish/functions/expand_rootfs.fish".text = builtins.readFile ./helpers/expand_rootfs.fish;

    "fish/functions/fix-steam-bwrap.fish".text = builtins.readFile ./helpers/fix-steam-bwrap.fish;

    "fish/functions/setup_nixos.fish".text = builtins.readFile ./helpers/setup_nixos.fish;

    "fish/functions/setup_nixos_config.fish".text = builtins.readFile ./helpers/setup_nixos_config.fish;
  };

  # You can still provide helpful CLI wrappers as actual binaries if needed
  environment.systemPackages = with pkgs; [
    fish
    starship
    eza
  ];
}
