# Global Environment Variables Module
#
# Purpose: Set system-wide environment variables for all users
# Dependencies: userConfig
# Related: fish.nix, main_configuration/home_modules/environment.nix
#
# This module:
# - Sets global environment variables accessible to all processes
# - Configures NixOS-specific paths and host information
{
  config,
  userConfig,
  ...
}: {
  environment.variables = {
    NIXOS_CONFIG_DIR = "$HOME/nixos-config";
    NIXOS_FLAKE_HOSTNAME = userConfig.host.hostname;
    EDITOR = userConfig.defaultApps.editor.command;
    VISUAL = "$EDITOR";
    PATH = "$HOME/bin:$HOME/.npm-global/bin:$PATH";
  };
}
