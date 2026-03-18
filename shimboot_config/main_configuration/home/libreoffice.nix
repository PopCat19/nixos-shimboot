# LibreOffice Module
#
# Purpose: Configure LibreOffice office suite
# Dependencies: None
#
# This module:
# - Installs LibreOffice via home-manager packages
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    libreoffice
  ];
}
