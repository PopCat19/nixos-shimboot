# Global Environment Variables Module
#
# Purpose: Set system-wide environment variables for all users
#
# This module:
# - Sets global environment variables accessible to all processes
# - Configures NixOS-specific paths and host information
#
# Priority strategy:
# - EDITOR/VISUAL: Normal assignment (priority 100) to override NixOS defaults (mkDefault, priority 1000)
# - Path variables: mkDefault (priority 1000) to allow consumer overrides
{ lib, userConfig, ... }:
{
  environment.variables = {
    # Override NixOS defaults with definitive values
    EDITOR = userConfig.defaultApps.editor.command;
    VISUAL = userConfig.defaultApps.editor.command;
    
    # Allow consumer override
    NIXOS_CONFIG_DIR = lib.mkDefault userConfig.env.NIXOS_CONFIG_DIR;
    NIXOS_CONFIG_PATH = lib.mkDefault "${userConfig.env.NIXOS_CONFIG_DIR}/shimboot_config";
    NIXOS_FLAKE_HOSTNAME = lib.mkDefault userConfig.host.hostname;
    PATH = lib.mkDefault "$HOME/bin:$HOME/.npm-global/bin:$PATH";
  };
}
