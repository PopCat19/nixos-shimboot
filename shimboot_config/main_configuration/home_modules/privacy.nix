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
  config,
  lib,
  userConfig,
  ...
}: let
  passwordsDir = "${userConfig.directories.home}/Passwords";
  keepassDb = "${passwordsDir}/keepass.kdbx";

  kpxcWrapper = pkgs.writeShellScriptBin "kpxc" ''
    set -e
    DB="${keepassDb}"
    if [ -f "$DB" ]; then
      exec ${pkgs.keepassxc}/bin/keepassxc "$DB" "$@"
    else
      exec ${pkgs.keepassxc}/bin/keepassxc "$@"
    fi
  '';
in {
  home.packages = with pkgs; [
    keepassxc
    kpxcWrapper
  ];

  home.activation.createPasswordsDir = lib.hm.dag.entryAfter ["writeBoundary"] ''
    mkdir -p ${passwordsDir}
  '';
}
