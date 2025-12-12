# Theme Qt Module
#
# Purpose: Configure Qt theming and appearance settings
# Dependencies: theme packages
# Related: theme.nix
#
# This module:
# - Configures Qt style settings
# - Sets up Kvantum theme engine
# - Manages Qt application appearance
{
  pkgs,
  config,
  inputs,
  ...
}: let
  inherit (import ./colors.nix {inherit pkgs config inputs;}) defaultVariant;
  kvantumPkg = pkgs.kdePackages.qtstyleplugin-kvantum;
in {
  qt = {
    enable = true;
    style = {
      name = "kvantum";
      package = kvantumPkg;
    };
  };
}