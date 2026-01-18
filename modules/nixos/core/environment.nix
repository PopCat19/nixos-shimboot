# Global Environment Variables Module
#
# Purpose: Set system-wide environment variables for all users
# Dependencies: vars
# Related: fish.nix, main_configuration/home/environment.nix
#
# This module:
# - Sets global environment variables accessible to all processes
# - Configures NixOS-specific paths and host information
{ vars, ... }:
{
  environment.variables = {
    NIXOS_CONFIG_DIR = "$HOME/nixos-config";
    NIXOS_FLAKE_HOSTNAME = vars.host.hostname;
    EDITOR = vars.defaultApps.editor.command;
    VISUAL = "$EDITOR";
    PATH = "$HOME/bin:$HOME/.npm-global/bin:$PATH";
  };
}
