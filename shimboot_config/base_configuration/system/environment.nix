# Global Environment Variables Module
#
# Purpose: Set system-wide environment variables for all users
#
# This module:
# - Sets global environment variables accessible to all processes
# - Configures NixOS-specific paths and host information
{ lib, userConfig, ... }:
{
  environment.variables = {
    NIXOS_CONFIG_DIR = lib.mkDefault userConfig.env.NIXOS_CONFIG_DIR;
    NIXOS_CONFIG_PATH = lib.mkDefault "${userConfig.env.NIXOS_CONFIG_DIR}/shimboot_config";
    NIXOS_FLAKE_HOSTNAME = lib.mkDefault userConfig.host.hostname;
    EDITOR = lib.mkDefault userConfig.defaultApps.editor.command;
    VISUAL = lib.mkDefault userConfig.defaultApps.editor.command;
    PATH = lib.mkDefault "$HOME/bin:$HOME/.npm-global/bin:$PATH";
  };
}
