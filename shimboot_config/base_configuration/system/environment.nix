# Global Environment Variables Module
#
# Purpose: Set system-wide environment variables for all users
# Dependencies: userConfig
# Related: fish.nix, main_configuration/home/environment.nix
#
# This module:
# - Sets global environment variables accessible to all processes
# - Configures NixOS-specific paths and host information
{ userConfig, ... }:
{
  environment.variables = {
    inherit (userConfig.env) NIXOS_CONFIG_DIR;
    NIXOS_CONFIG_PATH = "${userConfig.env.NIXOS_CONFIG_DIR}/shimboot_config";
    NIXOS_FLAKE_HOSTNAME = userConfig.host.hostname;
    EDITOR = userConfig.defaultApps.editor.command;
    VISUAL = userConfig.defaultApps.editor.command;
    PATH = "$HOME/bin:$HOME/.npm-global/bin:$PATH";
  };
}
