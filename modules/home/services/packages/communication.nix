# Communication Packages Module
#
# Purpose: Install communication and messaging applications
# Dependencies: None
# Related: packages.nix
#
# This module:
# - Installs communication applications
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    vesktop
  ];
}
