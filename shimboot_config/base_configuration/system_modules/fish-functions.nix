# Fish Functions Configuration Module
#
# Purpose: Configure Fish shell with custom functions and abbreviations
# Dependencies: fish, starship, eza
# Related: fish.nix, packages.nix
#
# This module:
# - Sets up environment variables for NixOS configuration
# - Loads custom Fish functions from external files
# - Defines shell abbreviations for common commands
# - Configures Starship prompt initialization

{
  lib,
  pkgs,
  userConfig,
  ...
}: {
  programs.fish = {
    shellInit = ''
      set -Ux NIXOS_CONFIG_DIR $HOME/nixos-config
      set -Ux NIXOS_FLAKE_HOSTNAME ${userConfig.host.hostname}
      set -Ux EDITOR ${userConfig.defaultApps.editor.command}

      fish_add_path $HOME/bin
      fish_add_path $HOME/.npm-global/bin
      if status is-interactive
        starship init fish | source
      end
    '';

    functions = {
      list-fish-helpers = let
        content = builtins.readFile ./fish_functions/list-fish-helpers.fish;
        lines = lib.splitString "\n" content;
      in
        lib.concatStringsSep "\n" (lib.sublist 1 (lib.length lines - 2) lines);

      nixos-rebuild-basic = let
        content = builtins.readFile ./fish_functions/nixos-rebuild-basic.fish;
        lines = lib.splitString "\n" content;
      in
        lib.concatStringsSep "\n" (lib.sublist 1 (lib.length lines - 2) lines);

      nixos-flake-update = let
        content = builtins.readFile ./fish_functions/nixos-flake-update.fish;
        lines = lib.splitString "\n" content;
      in
        lib.concatStringsSep "\n" (lib.sublist 1 (lib.length lines - 2) lines);

      fix-fish-history = let
        content = builtins.readFile ./fish_functions/fix-fish-history.fish;
        lines = lib.splitString "\n" content;
      in
        lib.concatStringsSep "\n" (lib.sublist 1 (lib.length lines - 2) lines);
    };

    shellAbbrs = {
      ".." = "cd ..";
      "..." = "cd ../..";
      ".3" = "cd ../../..";
      ".4" = "cd ../../../..";
      ".5" = "cd ../../../../..";

      mkdir = "mkdir -p";
      l = "eza -lh --icons=auto";
      ls = "eza -1 --icons=auto";
      ll = "eza -lha --icons=auto --sort=name --group-directories-first";
      ld = "eza -lhD --icons=auto";
      lt = "eza --tree --icons=auto";

      nconf = "$EDITOR $NIXOS_CONFIG_DIR/configuration.nix";
      hconf = "$EDITOR $NIXOS_CONFIG_DIR/home.nix";
      flconf = "$EDITOR $NIXOS_CONFIG_DIR/flake.nix";
      flup = "nixos-flake-update";
      ngit = "begin; cd $NIXOS_CONFIG_DIR; git $argv; cd -; end";
      cdh = "cd $NIXOS_CONFIG_DIR";

      nrb = "nixos-rebuild-basic";
      pkgs = "nix search nixpkgs";
      nsp = "nix-shell -p";

      gac = "git add . && git commit -m $argv";
      greset = "git reset --hard && git clean -fd";
      sillytavern = "begin; cd ~/SillyTavern-Launcher/SillyTavern; git pull origin staging 2>/dev/null; or true; ./start.sh; cd -; end";

      fixhist = "fix-fish-history";
    };
  };
}
