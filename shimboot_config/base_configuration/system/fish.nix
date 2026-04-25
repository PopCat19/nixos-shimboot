# Fish Shell Configuration Module
#
# Purpose: Configure Fish shell with functions, abbreviations, and Starship prompt
#
# This module:
# - Enables Fish as the default shell
# - Sets up environment variables for NixOS configuration
# - Loads custom Fish functions from external files
# - Defines shell abbreviations for common commands
# - Configures Starship prompt
#
# Opt-out: set shimboot.fish.enable = false to disable all shimboot fish config
#          set shimboot.fish.enableFunctions = false to skip function installation
#          set shimboot.fish.enableAbbreviations = false to skip abbreviations
{
  lib,
  pkgs,
  config,
  userConfig,
  ...
}:
let
  cfg = config.shimboot.fish;
  userData = userConfig.user or userConfig;
  username = userData.username or userConfig.username;

  # Core abbreviations that are always installed (QoL)
  # Users can remap these via their own fish config
  coreAbbrs = ''
    abbr -a nrb nixos-rebuild-basic
    abbr -a cdn 'cd $NIXOS_CONFIG_DIR'
    abbr -a scuts show-shortcuts
    abbr -a lfh list-fish-helpers
  '';
in
{
  options.shimboot.fish = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable shimboot fish functions, abbreviations, and starship prompt";
    };

    enableFunctions = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install system-wide fish functions (nixos-rebuild-basic, proxy helpers, etc.)";
    };

    enableAbbreviations = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install fish abbreviations (nrb, cdn, scuts, lfh)";
    };
  };

  config = lib.mkIf cfg.enable {
    # Priority 500: beats NixOS mkDefault (1000), consumers override with normal (100)
    # See environment.nix for full priority stack documentation
    programs.fish.enable = lib.mkOverride 500 true;
    programs.starship = lib.mkIf cfg.enableFunctions {
      enable = lib.mkOverride 500 true;
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

    programs.fish.interactiveShellInit = lib.mkIf cfg.enableAbbreviations ''
      # Source SoT environment variables from Nix
      set -gx SOT_USERNAME ${username}
      set -gx SOT_SHELL ${userData.shellPackage or "fish"}
      set -gx SOT_TERM_CMD ${userConfig.defaultApps.terminal.command}
      set -gx SOT_EDITOR_CMD ${userConfig.defaultApps.editor.command}

      if not contains /etc/fish/functions $fish_function_path
          set -g fish_function_path /etc/fish/functions $fish_function_path
      end

      ${coreAbbrs}
    '';

    environment.etc = lib.mkIf cfg.enableFunctions {
      "fish/conf.d/00-shimboot.fish".text = ''
        if status is-interactive
          starship init fish | source
        end
      '';

      "fish/functions/fish_greeting.fish".text = builtins.readFile ./fish_functions/fish-greeting.fish;

      "fish/functions/nixos-rebuild-basic.fish".text =
        builtins.readFile ./fish_functions/nixos-rebuild-basic.fish;

      "fish/functions/nixos-rebuild-auto.fish".text =
        builtins.readFile ./fish_functions/nixos-rebuild-auto.fish;

      "fish/functions/shimboot-kernel-needs-sandbox.fish".text =
        builtins.readFile ./fish_functions/shimboot-kernel-needs-sandbox.fish;

      "fish/functions/list-fish-helpers.fish".text =
        builtins.readFile ./fish_functions/list-fish-helpers.fish;

      "fish/functions/show-shortcuts.fish".text = builtins.readFile ./fish_functions/show-shortcuts.fish;
    };

    # You can still provide helpful CLI wrappers as actual binaries if needed
    environment.systemPackages = with pkgs; [
      fish
      starship
    ];
  };
}
