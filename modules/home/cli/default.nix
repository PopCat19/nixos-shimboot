# CLI Tools Modules
#
# Purpose: Bundle command-line interface tools and terminal configuration
# Dependencies: All CLI modules in this directory
# Related: modules/home/core, modules/home/desktop
#
# This bundle:
# - Configures Kitty terminal
# - Sets up Micro editor
# - Configures Fuzzel launcher
# - Sets up Fcitx5 input method
{ pkgs, ... }:
{
  imports = [
    ./kitty.nix
    ./micro.nix
    ./fuzzel.nix
    ./fcitx5.nix
  ];
}
