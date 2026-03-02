# plugins.nix
#
# Purpose: Declare and configure Neovim plugins
#
# This module:
# - Enables telescope, treesitter, gitsigns, lualine, oil, and which-key
{ pkgs, ... }:
{
  programs.nixvim.plugins = {
    telescope = {
      enable = true;
      extensions.fzf-native.enable = true;
    };

    treesitter = {
      enable = true;
      settings = {
        highlight.enable = true;
        indent.enable = true;
      };
      grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
        nix
        lua
        bash
        fish
        toml
        json
        yaml
        markdown
      ];
    };

    gitsigns = {
      enable = true;
      settings.signs = {
        add.text = "▎";
        change.text = "▎";
        delete.text = "";
        topdelete.text = "";
        changedelete.text = "▎";
      };
    };

    lualine = {
      enable = true;
    };

    oil = {
      enable = true;
      settings.default_file_explorer = true;
    };

    which-key.enable = true;

    toggleterm = {
      enable = true;
      settings = {
        direction = "float";
        shell = "fish";
        float_opts.border = "curved";
      };
    };

    direnv.enable = true;
  };
}
