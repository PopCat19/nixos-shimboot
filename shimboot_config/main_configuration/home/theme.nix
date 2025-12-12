# Theme Module
#
# Purpose: Configure Rose Pine theme across GTK, Qt, and desktop environments
# Dependencies: rose-pine packages, inputs
# Related: environment.nix
#
# This module:
# - Imports all theme configuration modules
# - Combines theme components into unified configuration
# - Provides centralized theme management
{
  lib,
  pkgs,
  config,
  inputs,
  userConfig,
  ...
}: {
  imports = [
    ./theme_config/colors.nix
    ./theme_config/fonts.nix
    ./theme_config/packages.nix
    ./theme_config/session.nix
    ./theme_config/gtk.nix
    ./theme_config/qt.nix
    ./theme_config/dconf.nix
    ./theme_config/files.nix
  ];
}
