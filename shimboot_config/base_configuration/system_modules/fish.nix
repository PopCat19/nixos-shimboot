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
  userConfig,
  ...
}: {
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
  '';

  environment.etc = {
    # Global env setup
    "fish/conf.d/00-shimboot.fish".text = ''
      # NixOS Shimboot system-wide setup
      set -Ux NIXOS_CONFIG_DIR $HOME/nixos-config
      set -Ux NIXOS_FLAKE_HOSTNAME ${userConfig.host.hostname}
      set -Ux EDITOR ${userConfig.defaultApps.editor.command}

      # Add common paths
      fish_add_path $HOME/bin
      fish_add_path $HOME/.npm-global/bin

      if status is-interactive
        starship init fish | source
      end
    '';

    # Function definitions
    "fish/functions/fish_greeting.fish".text =
      builtins.readFile ./fish_functions/fish-greeting.fish;

    "fish/functions/nixos-rebuild-basic.fish".text =
      builtins.readFile ./fish_functions/nixos-rebuild-basic.fish;

    "fish/functions/nixos-flake-update.fish".text =
      builtins.readFile ./fish_functions/nixos-flake-update.fish;

    "fish/functions/fix-fish-history.fish".text =
      builtins.readFile ./fish_functions/fix-fish-history.fish;

    "fish/functions/list-fish-helpers.fish".text =
      builtins.readFile ./fish_functions/list-fish-helpers.fish;

  };

  # You can still provide helpful CLI wrappers as actual binaries if needed
  environment.systemPackages = with pkgs; [fish starship eza];
}
