# Helpers Module
#
# Purpose: Provide system packages for helper scripts
# Dependencies: bash, ./*.sh files
# Related: system modules
#
# This module:
# - Installs helper scripts as system packages
# - Scripts are standalone bash executables
# - No fish dependency required
{ pkgs, ... }:
{
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "fix-steam-bwrap" (builtins.readFile ./fix-steam-bwrap.sh))
    (pkgs.writeShellScriptBin "expand_rootfs" (builtins.readFile ./expand_rootfs.sh))
    (pkgs.writeShellScriptBin "setup_nixos_config" (builtins.readFile ./setup_nixos_config.sh))
    (pkgs.writeShellScriptBin "setup_nixos" (builtins.readFile ./setup_nixos.sh))
  ];
}
