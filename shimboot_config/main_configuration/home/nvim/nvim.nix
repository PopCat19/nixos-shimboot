# nvim.nix
#
# Purpose: Configure Neovim via nixvim with modular plugin setup
#
# This module:
# - Imports nixvim home-manager module
# - Delegates options, plugins, keymaps, and LSP to submodules
{ inputs, ... }:
{
  imports = [
    inputs.nixvim.homeManagerModules.nixvim
    ./options.nix
    ./plugins.nix
    ./keymaps.nix
    ./lsp.nix
  ];

  programs.nixvim = {
    enable = true;
  };
}
