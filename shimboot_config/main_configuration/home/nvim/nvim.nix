# nvim.nix
#
# Purpose: Configure Neovim via nixvim
#
# This module:
# - Imports nixvim home-manager module
# - Sets core options
{ inputs, ... }:
{
  imports = [
    inputs.nixvim.homeManagerModules.nixvim
    ./options.nix
  ];

  programs.nixvim = {
    enable = true;
  };
}
