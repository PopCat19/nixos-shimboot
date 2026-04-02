# options.nix
#
# Purpose: Set core Neovim options
#
# This module:
# - Configures indentation, search, and display options
_: {
  programs.nixvim.opts = {
    number = true;
    relativenumber = true;
    expandtab = true;
    shiftwidth = 2;
    tabstop = 2;
    softtabstop = 2;
    smartindent = true;
    wrap = false;
    ignorecase = true;
    smartcase = true;
    termguicolors = true;
    scrolloff = 8;
    signcolumn = "yes";
    updatetime = 100;
    splitright = true;
    splitbelow = true;
  };
}
