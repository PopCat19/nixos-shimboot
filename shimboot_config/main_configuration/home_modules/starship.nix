{ pkgs, ... }:

{
  programs.starship = {
    enable = true;
    settings = {
      format = "$time$directory$git_branch$git_status$line_break$character";

      palette = "rose_pine";

      palettes.rose_pine = {
        base = "#191724";
        surface = "#1f1d2e";
        overlay = "#26233a";
        muted = "#6e6a86";
        subtle = "#908caa";
        text = "#e0def4";
        love = "#eb6f92";
        gold = "#f6c177";
        rose = "#ebbcba";
        pine = "#31748f";
        foam = "#9ccfd8";
        iris = "#c4a7e7";
        highlight_low = "#21202e";
        highlight_med = "#403d52";
        highlight_high = "#524f67";
      };

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
        disabled = false;
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
        disabled = false;
        format = "[$symbol$status]($style) ";
        symbol = "✖ ";
        style = "bold love";
      };
    };
  };
}