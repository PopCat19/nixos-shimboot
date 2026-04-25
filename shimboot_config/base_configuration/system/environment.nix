# Global Environment Variables Module
#
# Purpose: Set system-wide environment variables for all users
#
# This module:
# - Sets global environment variables accessible to all processes
# - Configures NixOS-specific paths and host information
#
# Priority strategy:
# - mkOverride 500: Beats NixOS mkDefault (1000), consumers override with normal (100)
{ lib, userConfig, ... }:
{
  environment.variables = {
    EDITOR = lib.mkOverride 500 userConfig.defaultApps.editor.command;
    VISUAL = lib.mkOverride 500 userConfig.defaultApps.editor.command;
    NIXOS_CONFIG_DIR = lib.mkOverride 500 userConfig.env.NIXOS_CONFIG_DIR;
    NIXOS_CONFIG_PATH = lib.mkOverride 500 "${userConfig.env.NIXOS_CONFIG_DIR}/shimboot_config";
    NIXOS_FLAKE_HOSTNAME = lib.mkOverride 500 userConfig.host.hostname;
    PATH = lib.mkOverride 500 "$HOME/bin:$HOME/.npm-global/bin:$PATH";
  };
}
