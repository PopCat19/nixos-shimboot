# Global Environment Variables Module
#
# Purpose: Set system-wide environment variables for all users
# Dependencies: userConfig, selectedProfile
# Related: fish.nix, main_configuration/home/environment.nix
#
# This module:
# - Sets global environment variables accessible to all processes
# - Configures NixOS-specific paths and host information
{ userConfig, selectedProfile, ... }:
{
  environment.variables = {
    NIXOS_CONFIG_DIR = userConfig.env.NIXOS_CONFIG_DIR;
    NIXOS_PROFILE_DIR = selectedProfile.NIXOS_PROFILE_DIR;
    NIXOS_FLAKE_HOSTNAME = userConfig.host.hostname;
    EDITOR = userConfig.defaultApps.editor.command;
    VISUAL = "$EDITOR";
    PATH = "$HOME/bin:$HOME/.npm-global/bin:$PATH";
  };
}
