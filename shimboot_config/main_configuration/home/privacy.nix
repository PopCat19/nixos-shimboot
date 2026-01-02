# Privacy and Security Module
#
# Purpose: Configure privacy tools and password management
# Dependencies: userConfig, KeePassXC packages
# Related: None
#
# This module:
# - Installs KeePassXC password manager
# - Creates wrapper script for synced database
# - Ensures passwords directory exists
{
  pkgs,
  lib,
  userConfig,
  ...
}: let
  passwordsDir = "${userConfig.directories.home}/Passwords";
  keepassDb = "${passwordsDir}/keepass.kdbx";
in {
  home.packages = with pkgs; [
    keepassxc
  ];

  programs.fish.shellAbbrs = {
    kpxc = "keepassxc ${keepassDb}";
  };

  home.activation.createPasswordsDir = lib.hm.dag.entryAfter ["writeBoundary"] ''
    mkdir -p ${passwordsDir}
  '';
}
