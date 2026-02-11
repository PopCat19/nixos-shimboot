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
}:
{
  programs.fish.enable = lib.mkDefault true;
  programs.starship = {
    enable = lib.mkDefault true;
    settings = {
      format = "$time$directory$git_branch$git_status$line_break$character";

      character = {
        success_symbol = "[❯](bold foam)";
        error_symbol = "[❯](bold love)";
        vimcmd_symbol = "[❮](bold iris)";
      };

      directory = {
        style = "bold iris";
        truncation_length = 3;
        truncate_to_repo = false;
        format = "[$path]($style)[$read_only]($read_only_style) ";
        read_only = " 󰌾";
        read_only_style = "love";
      };

      git_branch = {
        format = "[$symbol$branch(:$remote_branch)]($style) ";
        symbol = " ";
        style = "bold pine";
        only_attached = true;
      };

      git_status = {
        format = "([\\[$all_status$ahead_behind\\]]($style) )";
        style = "bold rose";
        conflicted = "=";
        ahead = "⇡\${count}";
        behind = "⇣\${count}";
        diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
        up_to_date = "";
        untracked = "?\${count}";
        stashed = "≡\${count}";
        modified = "!\${count}";
        staged = "+\${count}";
        renamed = "»\${count}";
        deleted = "✘\${count}";
      };

      cmd_duration = {
        format = "[$duration]($style) ";
        style = "bold gold";
        min_time = 2000;
      };

      hostname = {
        ssh_only = true;
        format = "[$hostname]($style) in ";
        style = "bold foam";
      };

      username = {
        show_always = false;
        format = "[$user]($style)@";
        style_user = "bold text";
        style_root = "bold love";
      };

      package = {
        format = "[$symbol$version]($style) ";
        symbol = "📦 ";
        style = "bold rose";
      };

      nodejs = {
        format = "[$symbol($version)]($style) ";
        symbol = " ";
        style = "bold pine";
      };

      python = {
        format = "[\${symbol}\${pyenv_prefix}(\${version})(\\($virtualenv\\))]($style) ";
        symbol = " ";
        style = "bold gold";
      };

      rust = {
        format = "[$symbol($version)]($style) ";
        symbol = " ";
        style = "bold love";
      };

      nix_shell = {
        format = "[$symbol$state(\\($name\\))]($style) ";
        symbol = " ";
        style = "bold iris";
        impure_msg = "[impure](bold love)";
        pure_msg = "[pure](bold foam)";
      };

      memory_usage = {
        disabled = true;
        threshold = 70;
        format = "[$symbol\${ram}(\${swap})]($style) ";
        symbol = "🐏 ";
        style = "bold subtle";
      };

      time = {
        disabled = false;
        format = "[$time]($style) ";
        style = "bold muted";
        time_format = "%T";
        utc_time_offset = "local";
      };

      status = {
        disabled = true;
        format = "[$symbol$status]($style) ";
        symbol = "✖ ";
        style = "bold love";
      };
    };
  };

  programs.fish.interactiveShellInit = ''
    # Source SoT environment variables from Nix
    set -gx SOT_USERNAME ${userConfig.user.username}
    set -gx SOT_SHELL ${userConfig.user.shellPackage}
    set -gx SOT_TERM_CMD ${userConfig.defaultApps.terminal.command}
    set -gx SOT_EDITOR_CMD ${userConfig.defaultApps.editor.command}
    set -gx NIXOS_CONFIG_DIR ${userConfig.env.NIXOS_CONFIG_DIR}

    # Make system-wide functions visible
    if not contains /etc/fish/functions $fish_function_path
        set -g fish_function_path /etc/fish/functions $fish_function_path
    end

    # Abbreviations for common NixOS commands
    abbr -a nrb nixos-rebuild-basic
    abbr -a flup nixos-flake-update
    abbr -a cdn 'cd $NIXOS_CONFIG_DIR'
    abbr -a scuts show-shortcuts
    abbr -a lsa lsa
    abbr -a proxy_on proxy_on
    abbr -a proxy_off proxy_off
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

    "fish/functions/show-shortcuts.fish".text = builtins.readFile ./fish_functions/show-shortcuts.fish;

    "fish/functions/lsa.fish".text = builtins.readFile ./fish_functions/lsa.fish;

    "fish/functions/proxy_on.fish".text = builtins.readFile ./fish_functions/proxy_on.fish;

    "fish/functions/proxy_off.fish".text = builtins.readFile ./fish_functions/proxy_off.fish;

    "fish/functions/proxify.fish".text = builtins.readFile ./fish_functions/proxify.fish;

    # Fish completions
    "fish/completions/proxify.fish".text = builtins.readFile ./fish_functions/completions/proxify.fish;

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
