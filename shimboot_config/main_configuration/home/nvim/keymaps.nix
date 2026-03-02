# keymaps.nix
#
# Purpose: Define Neovim keybindings
#
# This module:
# - Sets leader key and maps telescope, oil, and toggleterm commands
_: {
  programs.nixvim = {
    globals.mapleader = " ";

    keymaps = [
      {
        key = "<leader>ff";
        action = "<cmd>Telescope find_files<cr>";
        options.desc = "find files";
      }
      {
        key = "<leader>fg";
        action = "<cmd>Telescope live_grep<cr>";
        options.desc = "live grep";
      }
      {
        key = "<leader>fb";
        action = "<cmd>Telescope buffers<cr>";
        options.desc = "buffers";
      }
      {
        key = "<leader>e";
        action = "<cmd>Oil<cr>";
        options.desc = "open file explorer";
      }
      {
        key = "<leader>t";
        action = "<cmd>ToggleTerm<cr>";
        options.desc = "toggle terminal";
      }
      {
        key = "<leader>ca";
        action = "<cmd>lua vim.lsp.buf.code_action()<cr>";
        options.desc = "code action";
      }
      {
        key = "gd";
        action = "<cmd>lua vim.lsp.buf.definition()<cr>";
        options.desc = "go to definition";
      }
      {
        key = "K";
        action = "<cmd>lua vim.lsp.buf.hover()<cr>";
        options.desc = "hover docs";
      }
      {
        key = "<leader>rn";
        action = "<cmd>lua vim.lsp.buf.rename()<cr>";
        options.desc = "rename symbol";
      }
    ];
  };
}
